import SwiftUI
import os

/// Quick notes (ARCHITECTURE §5, §8, D31): one plain-text note in Application Support, saved `saveDelay` after the
/// last edit. Stays on the Mac and is never logged.
@MainActor
@Observable
final class NotesModule: NotchModule {
    let id = "notes"
    let title: LocalizedStringResource = "Notes"
    let systemImage = "note.text"
    let hasCompactContent = false

    /// The note as typed. Each edit restarts the save delay.
    var text = "" {
        didSet { if text != savedText { scheduleSave() } }
    }
    /// The file exists but couldn't be read. Saving stays off, so it is never overwritten with an empty note.
    private(set) var loadFailed = false

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let saveDelay: Duration
    /// What the file holds, so a load or an unchanged note writes nothing.
    @ObservationIgnored private var savedText = ""
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    /// `fileURL` and `saveDelay` are internal for tests.
    init(fileURL: URL = .applicationSupportDirectory.appending(path: "DropNotch/Notes/note.txt"),
         saveDelay: Duration = .seconds(1)) {
        self.fileURL = fileURL
        self.saveDelay = saveDelay
    }

    func compactView(slot: CompactSlot) -> AnyView { AnyView(EmptyView()) }

    func expandedView() -> AnyView { AnyView(NotesExpandedView(module: self)) }

    func settingsView() -> AnyView { AnyView(EmptyView()) }

    // shortcut: reads and writes on the main thread; a note is a few KB, so each is well under a frame. Move them
    // off the main thread if notes grow to megabytes.
    func start() {
        loadFailed = false
        do {
            let loaded = try String(contentsOf: fileURL, encoding: .utf8)
            savedText = loaded
            text = loaded
        } catch CocoaError.fileReadNoSuchFile {
            // First run: no note yet.
        } catch {
            loadFailed = true
            // The error code only: the path and the note stay out of the log.
            Logger.notes.error("Note read failed: \((error as NSError).domain, privacy: .public) \((error as NSError).code)")
        }
    }

    /// Writes any unsaved edit straight away (app quit, module turned off).
    func stop() {
        saveTask?.cancel()
        saveTask = nil
        save()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        // One wake per pause in typing, never repeating (ARCHITECTURE §9).
        saveTask = Task { [weak self, saveDelay] in
            try? await Task.sleep(for: saveDelay)
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    private func save() {
        guard !loadFailed, text != savedText else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Atomic: a crash mid-write leaves the old note, never half of the new one.
            try Data(text.utf8).write(to: fileURL, options: .atomic)
            savedText = text
        } catch {
            // Kept in memory; the next edit or `stop()` tries again.
            Logger.notes.error("Note save failed: \((error as NSError).domain, privacy: .public) \((error as NSError).code)")
        }
    }
}
