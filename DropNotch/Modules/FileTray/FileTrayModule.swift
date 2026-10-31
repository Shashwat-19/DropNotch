import AppKit
import SwiftUI
import os

/// The file tray (ARCHITECTURE §5, §8, D6, D32). Dropped files are kept as bookmarks to the originals, which never
/// move; a drop with no file behind it (a file promise, e.g. from Photos or Mail) or a file that can't be bookmarked
/// is copied into the tray's storage instead. The list persists in tray.json. File names and paths are never logged.
@MainActor
@Observable
final class FileTrayModule: NotchModule {
    let id = "file-tray"
    let title: LocalizedStringResource = "Tray"
    let systemImage = "tray"
    let hasCompactContent = false

    private(set) var items: [TrayItem] = []
    /// Where each item's file is now. An item with no entry is missing and shown greyed out (D6).
    private(set) var locations: [UUID: URL] = [:]
    /// Selected items, for AirDrop, Share, Remove and dragging several at once.
    var selection: Set<UUID> = []
    /// tray.json exists but couldn't be read. Saving stays off, so it is never overwritten with an empty tray.
    private(set) var loadFailed = false
    /// The last save failed. The tray is still in memory; the next change tries again.
    private(set) var saveFailed = false

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let storageURL: URL
    /// Promised files are written by the source app; the reader block runs here, off the main thread.
    @ObservationIgnored private let promiseQueue = OperationQueue()
    /// Kept here, not in the view: a transfer outlives the open notch, whose view goes when it closes (code-reviewer S3).
    @ObservationIgnored let airDrop = NSSharingService(named: .sendViaAirDrop)

    /// Both URLs are internal for tests.
    init(fileURL: URL = .applicationSupportDirectory.appending(path: "DropNotch/tray.json"),
         storageURL: URL = .applicationSupportDirectory.appending(path: "DropNotch/Tray")) {
        self.fileURL = fileURL
        self.storageURL = storageURL
        promiseQueue.qualityOfService = .userInitiated
    }

    func compactView(slot: CompactSlot) -> AnyView { AnyView(EmptyView()) }

    func expandedView() -> AnyView { AnyView(FileTrayExpandedView(module: self)) }

    func settingsView() -> AnyView { AnyView(EmptyView()) }

    /// Loads the list only. Bookmarks are resolved when the tray is shown (`refresh()`), so a folder-access prompt
    /// for Desktop, Documents or Downloads appears when the user looks at the tray, not at launch.
    func start() {
        loadFailed = false
        do {
            let decoded = try JSONDecoder().decode([TrayItem].self, from: Data(contentsOf: fileURL))
            // An edited file can't make a copy's path leave its folder.
            items = decoded.filter { ($0.bookmark != nil) != ($0.copyFolder != nil) && $0.hasSafeName }
        } catch CocoaError.fileReadNoSuchFile {
            items = []
        } catch {
            items = []
            loadFailed = true
            Logger.tray.error("Tray read failed: \((error as NSError).domain, privacy: .public) \((error as NSError).code)")
        }
        locations = [:]
        selection = []
    }

    /// Every change is saved straight away, so there is nothing to flush.
    func stop() {}

    /// Finds where each item's file is now, and refreshes bookmarks that macOS reports as stale.
    // shortcut: resolves every bookmark on the main thread each time the tray is shown; fine for tens of local
    // items, move off the main thread if trays grow to hundreds or bookmarks to slow volumes.
    func refresh() {
        var changed = false
        locations = items.indices.reduce(into: [:]) { result, index in
            let item = items[index]
            guard let bookmark = item.bookmark else {
                if let url = copyURL(item), FileManager.default.fileExists(atPath: url.path) { result[item.id] = url }
                return
            }
            var isStale = false
            // `.withoutMounting`: a bookmark to an unmounted server or disk is missing, rather than mounting it.
            guard let url = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting],
                                     relativeTo: nil, bookmarkDataIsStale: &isStale),
                  FileManager.default.fileExists(atPath: url.path),
                  // A bookmark follows a file into the Trash; the user threw it away, so it counts as missing.
                  !url.pathComponents.contains(where: { $0 == ".Trash" || $0 == ".Trashes" }) else { return }
            result[item.id] = url
            if isStale, let fresh = try? url.bookmarkData() {
                items[index].bookmark = fresh
                items[index].name = url.lastPathComponent
                changed = true
            }
        }
        if changed { save() }
    }

    /// Adds dropped file URLs as bookmarks. A file already in the tray isn't added twice.
    func add(_ urls: [URL]) {
        guard !urls.isEmpty, !loadFailed else { return }
        refresh()
        // Both sides through `resolvingSymlinksInPath()`: it drops a leading /private that bookmark resolution keeps.
        var present = Set(locations.values.map { $0.resolvingSymlinksInPath().path })
        for dropped in urls {
            // A symlink is followed, so the tray holds the file the user meant, not the link (D32).
            let url = dropped.resolvingSymlinksInPath()
            guard present.insert(url.path).inserted else { continue }
            do {
                items.append(TrayItem(id: UUID(), name: url.lastPathComponent, bookmark: try url.bookmarkData()))
                locations[items[items.count - 1].id] = url
            } catch {
                Logger.tray.error("Bookmark failed, copying: \((error as NSError).domain, privacy: .public) \((error as NSError).code)")
                copyIn(url)
            }
        }
        save()
    }

    /// Receives promised files (no file behind the drop, e.g. Photos, Mail, a browser image) into the tray's storage.
    func receive(_ receivers: [NSFilePromiseReceiver]) {
        guard !loadFailed else { return }
        for receiver in receivers {
            let folderID = UUID()
            let folder = storageURL.appending(path: folderID.uuidString)
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            } catch {
                Logger.tray.error("Tray folder failed: \((error as NSError).domain, privacy: .public) \((error as NSError).code)")
                continue
            }
            receiver.receivePromisedFiles(atDestination: folder, options: [:], operationQueue: promiseQueue) { [weak self] url, error in
                Task { @MainActor in self?.received(url, error: error, folderID: folderID) }
            }
        }
    }

    /// Removes items from the tray. Originals are never touched; only the tray's own copies are deleted.
    func remove(_ ids: Set<UUID>) {
        for item in items where ids.contains(item.id) {
            deleteCopy(of: item)
        }
        items.removeAll { ids.contains($0.id) }
        ids.forEach { locations[$0] = nil }
        selection.subtract(ids)
        save()
    }

    func clear() { remove(Set(items.map(\.id))) }

    /// A click selects only this item; ⌘-click adds or removes it.
    func select(_ id: UUID, extending: Bool) {
        if !extending {
            selection = [id]
        } else if selection.remove(id) == nil {
            selection.insert(id)
        }
    }

    /// The files AirDrop and Share send: the selected ones, or all of them when nothing is selected. Missing files
    /// are left out.
    var shareURLs: [URL] {
        let chosen = selection.isEmpty ? items : items.filter { selection.contains($0.id) }
        return chosen.compactMap { locations[$0.id] }
    }

    /// The files a drag from `id` carries: every selected file if `id` is selected, else only its own.
    func dragURLs(from id: UUID) -> [URL] {
        selection.contains(id) ? shareURLs : locations[id].map { [$0] } ?? []
    }

    /// Where a copy lives: `<storage>/<folder>/<name>`. Nil for a bookmark or an unsafe name.
    func copyURL(_ item: TrayItem) -> URL? {
        guard let folder = item.copyFolder, item.hasSafeName else { return nil }
        return storageURL.appending(path: folder.uuidString).appending(path: item.name)
    }

    /// The fallback when a file can't be bookmarked (D6). Off the main thread: the file may be large.
    private func copyIn(_ source: URL) {
        let item = TrayItem(id: UUID(), name: source.lastPathComponent, copyFolder: UUID())
        guard let destination = copyURL(item) else { return }
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: source, to: destination)
            } catch {
                try? FileManager.default.removeItem(at: destination.deletingLastPathComponent())
                Logger.tray.error("Copy failed: \((error as NSError).domain, privacy: .public) \((error as NSError).code)")
                return
            }
            await self?.insert(item, at: destination)
        }
    }

    private func received(_ url: URL, error: Error?, folderID: UUID) {
        let folder = storageURL.appending(path: folderID.uuidString)
        let item = TrayItem(id: UUID(), name: url.lastPathComponent, copyFolder: folderID)
        // The source app chose the name and wrote the file; anything outside the folder we gave it isn't ours.
        // Folders compared by path, as a promised folder's URL can end in "/" (code-reviewer W2).
        let ours = item.hasSafeName && url.deletingLastPathComponent().standardizedFileURL.path == folder.standardizedFileURL.path
        // A promised symlink could point at a file the source can't read itself, which Share would then send (L1).
        let isLink = (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true
        guard error == nil, ours, !isLink, let location = copyURL(item) else {
            if let error {
                Logger.tray.error("Promise failed: \((error as NSError).domain, privacy: .public) \((error as NSError).code)")
            }
            // A partial write would otherwise sit in the storage with no item pointing at it.
            if ours { try? FileManager.default.removeItem(at: url) }
            removeFolderIfEmpty(folder)
            return
        }
        insert(item, at: location)
    }

    private func insert(_ item: TrayItem, at url: URL) {
        // A relaunch of the module may have found tray.json unreadable while the copy ran.
        guard !loadFailed else { return deleteCopy(of: item) }
        items.append(item)
        locations[item.id] = url
        save()
    }

    /// Deletes a copy and its folder once empty. `copyURL` keeps the path inside the tray's storage, and
    /// `removeItem` deletes a symlink itself, never what it points to.
    private func deleteCopy(of item: TrayItem) {
        guard let url = copyURL(item), isOwnFolder(url.deletingLastPathComponent()) else { return }
        try? FileManager.default.removeItem(at: url)
        removeFolderIfEmpty(url.deletingLastPathComponent())
    }

    private func removeFolderIfEmpty(_ folder: URL) {
        guard isOwnFolder(folder) else { return }
        if (try? FileManager.default.contentsOfDirectory(atPath: folder.path))?.isEmpty == true {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    /// Whether the storage folder and this item folder are real folders, not symlinks. Another process could plant
    /// `Tray/<UUID>` → ~/Documents and a copy item named after a document there; Remove would then delete the
    /// document (security-auditor M1). `attributesOfItem` doesn't follow a symlink in the last component.
    // shortcut: checked, then deleted by path, so a swap in between still wins; upgrade to `openat`/`unlinkat`
    // with O_NOFOLLOW if the tray ever deletes on another process's schedule.
    private func isOwnFolder(_ folder: URL) -> Bool {
        [storageURL, folder].allSatisfy {
            (try? FileManager.default.attributesOfItem(atPath: $0.path))?[.type] as? FileAttributeType == .typeDirectory
        }
    }

    private func save() {
        guard !loadFailed else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Atomic: a crash mid-write leaves the old list, never half of the new one.
            try JSONEncoder().encode(items).write(to: fileURL, options: .atomic)
            saveFailed = false
        } catch {
            saveFailed = true
            Logger.tray.error("Tray save failed: \((error as NSError).domain, privacy: .public) \((error as NSError).code)")
        }
    }
}
