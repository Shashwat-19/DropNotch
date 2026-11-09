import XCTest
@testable import DropNotch

@MainActor
final class FileTrayModuleTests: XCTestCase {
    private var directory: URL!

    /// A fresh folder per test, so nothing touches the real Application Support tray.
    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appending(path: "FileTrayModuleTests-\(UUID())")
        try? FileManager.default.createDirectory(at: directory.appending(path: "Originals"), withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    /// In a subfolder that doesn't exist yet, so saving must create it.
    private var fileURL: URL { directory.appending(path: "Support/tray.json") }
    private var storageURL: URL { directory.appending(path: "Support/Tray") }
    /// One level above storageURL: a delete that escapes the storage would hit this.
    private var sentinel: URL { directory.appending(path: "Support/x") }

    private func makeModule() -> FileTrayModule { FileTrayModule(fileURL: fileURL, storageURL: storageURL) }

    @discardableResult
    private func original(_ name: String, _ text: String = "original") throws -> URL {
        let url = directory.appending(path: "Originals/\(name)")
        try Data(text.utf8).write(to: url)
        return url
    }

    private func writeTray(_ items: [TrayItem]) throws { try writeTray(JSONEncoder().encode(items)) }

    private func writeTray(_ data: Data) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL)
    }

    private func savedItems() throws -> [TrayItem] { try JSONDecoder().decode([TrayItem].self, from: Data(contentsOf: fileURL)) }

    /// A copy item plus its file under `<storage>/<folder>/<name>`.
    private func copyItem(_ name: String = "photo.jpg") throws -> TrayItem {
        let item = TrayItem(id: UUID(), name: name, copyFolder: UUID())
        let folder = storageURL.appending(path: item.copyFolder!.uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("copy".utf8).write(to: folder.appending(path: name))
        return item
    }

    /// Temp files live under /var, a symlink to /private/var; compare the real paths.
    private func path(_ url: URL?) -> String? { url?.resolvingSymlinksInPath().path }

    private func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }

    // MARK: - Loading

    func testIdentity() {
        let module = makeModule()
        XCTAssertEqual(module.id, "file-tray")
        XCTAssertFalse(module.hasCompactContent)
    }

    func testIsOnByDefault() {
        XCTAssertTrue(makeModule().isEnabledByDefault)
    }

    func testStartWithNoFileIsEmptyAndWritesNothing() {
        let module = makeModule()
        module.start()
        module.refresh()
        XCTAssertEqual(module.items, [])
        XCTAssertFalse(module.loadFailed)
        XCTAssertFalse(exists(fileURL))
    }

    func testCorruptFileSetsLoadFailedAndIsNeverOverwritten() throws {
        let corrupt = Data("{not json".utf8)
        try writeTray(corrupt)
        let module = makeModule()
        module.start()
        XCTAssertTrue(module.loadFailed)
        XCTAssertEqual(module.items, [])

        module.add([try original("a.txt")])
        XCTAssertEqual(module.items, [], "add is refused while the file is unreadable")
        module.remove([UUID()])
        module.clear()
        XCTAssertEqual(try Data(contentsOf: fileURL), corrupt)
    }

    func testStartAgainAfterTheFileIsFixedClearsLoadFailed() throws {
        try writeTray(Data("[{".utf8))
        let module = makeModule()
        module.start()
        XCTAssertTrue(module.loadFailed)
        try writeTray([])
        module.start()
        XCTAssertFalse(module.loadFailed)
        module.add([try original("a.txt")])
        XCTAssertEqual(try savedItems().count, 1)
    }

    // MARK: - Adding

    func testAddBookmarksPersistsAndSurvivesARelaunch() throws {
        let a = try original("a.txt", "alpha"), b = try original("b.txt", "beta")
        let past = Date(timeIntervalSince1970: 1_000_000)
        try FileManager.default.setAttributes([.modificationDate: past], ofItemAtPath: a.path)
        let module = makeModule()
        module.start()
        module.add([a, b])

        XCTAssertEqual(module.items.map(\.name), ["a.txt", "b.txt"])
        XCTAssertTrue(module.items.allSatisfy { $0.bookmark != nil && $0.copyFolder == nil })
        XCTAssertEqual(try savedItems(), module.items)
        XCTAssertFalse(exists(storageURL), "a bookmark makes no copy")

        let reloaded = makeModule()
        reloaded.start()
        XCTAssertEqual(reloaded.items, module.items)
        XCTAssertEqual(reloaded.locations, [:], "bookmarks are resolved when shown, not at start")
        reloaded.refresh()
        XCTAssertEqual(reloaded.items.map { path(reloaded.locations[$0.id]) }, [path(a), path(b)])

        // Originals stay where they were, unchanged.
        XCTAssertEqual(try String(contentsOf: a, encoding: .utf8), "alpha")
        XCTAssertEqual(try String(contentsOf: b, encoding: .utf8), "beta")
        let modified = try FileManager.default.attributesOfItem(atPath: a.path)[.modificationDate] as? Date
        XCTAssertEqual(modified, past)
    }

    func testAddingTheSameFileTwiceInOneDropKeepsOneItem() throws {
        let a = try original("a.txt")
        let module = makeModule()
        module.start()
        module.add([a, a])
        XCTAssertEqual(module.items.count, 1)
    }

    // Under /private (every test temp folder is), where `resolvingSymlinksInPath()` and bookmark resolution
    // disagree about the leading /private.
    func testAddingTheSameFileInALaterDropKeepsOneItem() throws {
        let a = try original("a.txt")
        let module = makeModule()
        module.start()
        module.add([a])
        module.add([a])
        XCTAssertEqual(module.items.count, 1, "in a later drop")
        let reloaded = makeModule()
        reloaded.start()
        reloaded.add([a])
        XCTAssertEqual(reloaded.items.count, 1, "after a relaunch")
    }

    func testAddingASymlinkHoldsItsTarget() throws {
        let target = try original("target.txt")
        let link = directory.appending(path: "Originals/link.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let module = makeModule()
        module.start()
        module.add([link, target])
        XCTAssertEqual(module.items.count, 1, "the link and its target are the same file")
        let item = try XCTUnwrap(module.items.first)
        XCTAssertEqual(item.name, "target.txt")
        XCTAssertEqual(path(module.locations[item.id]), path(target))

        let reloaded = makeModule()
        reloaded.start()
        reloaded.refresh()
        XCTAssertEqual(path(reloaded.locations[item.id]), path(target))
    }

    func testAddingNothingWritesNothing() {
        let module = makeModule()
        module.start()
        module.add([])
        XCTAssertFalse(exists(fileURL))
    }

    // MARK: - Refresh

    func testDeletedOriginalIsMissingButKept() throws {
        let a = try original("a.txt"), b = try original("b.txt")
        let module = makeModule()
        module.start()
        module.add([a, b])
        try FileManager.default.removeItem(at: a)
        module.refresh()
        XCTAssertEqual(module.items.count, 2, "a missing item stays, greyed out")
        XCTAssertNil(module.locations[module.items[0].id])
        XCTAssertEqual(path(module.locations[module.items[1].id]), path(b))
    }

    func testRenamedOriginalIsFollowed() throws {
        let a = try original("a.txt")
        let module = makeModule()
        module.start()
        module.add([a])
        let renamed = directory.appending(path: "Originals/renamed.txt")
        try FileManager.default.moveItem(at: a, to: renamed)

        let reloaded = makeModule()
        reloaded.start()
        reloaded.refresh()
        XCTAssertEqual(path(reloaded.locations[module.items[0].id]), path(renamed))
    }

    func testRefreshFindsACopyInStorage() throws {
        let present = try copyItem("here.jpg")
        let gone = TrayItem(id: UUID(), name: "gone.jpg", copyFolder: UUID())
        try writeTray([present, gone])
        let module = makeModule()
        module.start()
        module.refresh()
        XCTAssertEqual(module.items.count, 2)
        XCTAssertEqual(path(module.locations[present.id]),
                       path(storageURL.appending(path: "\(present.copyFolder!.uuidString)/here.jpg")))
        XCTAssertNil(module.locations[gone.id])
    }

    // MARK: - Removing

    func testRemoveAndClearNeverTouchOriginals() throws {
        let a = try original("a.txt", "alpha"), b = try original("b.txt", "beta")
        let module = makeModule()
        module.start()
        module.add([a, b])
        module.selection = Set(module.items.map(\.id))
        module.remove([module.items[0].id])
        XCTAssertEqual(module.items.map(\.name), ["b.txt"])
        XCTAssertEqual(module.selection, [module.items[0].id], "a removed item leaves the selection")
        XCTAssertEqual(try savedItems().map(\.name), ["b.txt"])
        module.clear()
        XCTAssertEqual(module.items, [])
        XCTAssertEqual(module.locations, [:])
        XCTAssertEqual(try savedItems(), [])
        XCTAssertEqual(try String(contentsOf: a, encoding: .utf8), "alpha")
        XCTAssertEqual(try String(contentsOf: b, encoding: .utf8), "beta")
    }

    func testRemovingACopyDeletesItAndItsEmptyFolder() throws {
        let removed = try copyItem("one.jpg"), kept = try copyItem("two.jpg")
        try writeTray([removed, kept])
        let module = makeModule()
        module.start()
        module.refresh()
        module.remove([removed.id])
        XCTAssertFalse(exists(storageURL.appending(path: removed.copyFolder!.uuidString)))
        XCTAssertTrue(exists(storageURL.appending(path: "\(kept.copyFolder!.uuidString)/two.jpg")))
        module.clear()
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: storageURL.path), [])
    }

    func testRemovingACopyKeepsAFolderThatIsNotEmpty() throws {
        let item = try copyItem("one.jpg")
        let folder = storageURL.appending(path: item.copyFolder!.uuidString)
        try Data().write(to: folder.appending(path: "other"))
        try writeTray([item])
        let module = makeModule()
        module.start()
        module.clear()
        XCTAssertFalse(exists(folder.appending(path: "one.jpg")))
        XCTAssertTrue(exists(folder.appending(path: "other")))
    }

    func testRemovingACopyThatIsASymlinkDeletesTheLinkOnly() throws {
        try FileManager.default.createDirectory(at: storageURL, withIntermediateDirectories: true)
        try Data("keep".utf8).write(to: sentinel)
        let item = TrayItem(id: UUID(), name: "link", copyFolder: UUID())
        let folder = storageURL.appending(path: item.copyFolder!.uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: folder.appending(path: "link"), withDestinationURL: sentinel)
        try writeTray([item])
        let module = makeModule()
        module.start()
        module.refresh()
        // Missing, so AirDrop, Share and drags never send what the link points to.
        XCTAssertNil(module.locations[item.id])
        module.clear()
        XCTAssertFalse(exists(folder))
        XCTAssertEqual(try String(contentsOf: sentinel, encoding: .utf8), "keep")
    }

    // security-auditor M1: a planted symlink as the item folder must not turn Remove into a delete elsewhere.
    func testRemovingACopyWhoseFolderIsASymlinkDeletesNothingThroughIt() throws {
        let document = try original("thesis.docx", "keep")
        let item = TrayItem(id: UUID(), name: "thesis.docx", copyFolder: UUID())
        try FileManager.default.createDirectory(at: storageURL, withIntermediateDirectories: true)
        let folder = storageURL.appending(path: item.copyFolder!.uuidString)
        try FileManager.default.createSymbolicLink(at: folder, withDestinationURL: document.deletingLastPathComponent())
        try writeTray([item])
        let module = makeModule()
        module.start()
        module.refresh()
        XCTAssertNil(module.locations[item.id], "never shared through the link")
        module.clear()
        XCTAssertEqual(try String(contentsOf: document, encoding: .utf8), "keep")
        XCTAssertTrue(module.items.isEmpty)
    }

    // MARK: - Edited tray.json

    func testUnsafeCopyNamesAreDroppedAndNothingOutsideStorageIsDeleted() throws {
        let legit = try copyItem("legit.jpg")
        try Data("keep".utf8).write(to: sentinel)
        try Data("keep".utf8).write(to: storageURL.appending(path: "x"))
        // Each reuses the legit folder, so a bad path would land on real files.
        let unsafe = ["../x", "../../x", "..", ".", "a/b", "", "legit.jpg\0"].map {
            TrayItem(id: UUID(), name: $0, copyFolder: legit.copyFolder)
        }
        try writeTray(unsafe + [legit])
        let module = makeModule()
        module.start()
        XCTAssertFalse(module.loadFailed)
        XCTAssertEqual(module.items, [legit])
        module.clear()
        XCTAssertEqual(try String(contentsOf: sentinel, encoding: .utf8), "keep")
        XCTAssertEqual(try String(contentsOf: storageURL.appending(path: "x"), encoding: .utf8), "keep")
        XCTAssertFalse(exists(storageURL.appending(path: legit.copyFolder!.uuidString)))
    }

    func testItemWithBothOrNeitherKindIsDropped() throws {
        let bookmark = try original("a.txt").bookmarkData()
        let both = TrayItem(id: UUID(), name: "both", bookmark: bookmark, copyFolder: UUID())
        let neither = TrayItem(id: UUID(), name: "neither")
        let good = TrayItem(id: UUID(), name: "a.txt", bookmark: bookmark)
        try writeTray([both, neither, good])
        let module = makeModule()
        module.start()
        XCTAssertEqual(module.items, [good])
    }

    func testCopyURLRefusesUnsafeNamesAndBookmarks() {
        let module = makeModule()
        for name in ["../x", "..", ".", "a/b", ""] {
            XCTAssertNil(module.copyURL(TrayItem(id: UUID(), name: name, copyFolder: UUID())), name)
        }
        XCTAssertNil(module.copyURL(TrayItem(id: UUID(), name: "a.txt", bookmark: Data())))
        let item = TrayItem(id: UUID(), name: "a.txt", copyFolder: UUID())
        XCTAssertEqual(module.copyURL(item), storageURL.appending(path: "\(item.copyFolder!.uuidString)/a.txt"))
    }

    // MARK: - Selection, share and drag

    func testSelectReplacesOrToggles() {
        let module = makeModule()
        let a = UUID(), b = UUID(), c = UUID()
        module.select(a, extending: false)
        XCTAssertEqual(module.selection, [a])
        module.select(b, extending: true)
        XCTAssertEqual(module.selection, [a, b])
        module.select(a, extending: true)
        XCTAssertEqual(module.selection, [b])
        module.select(c, extending: false)
        XCTAssertEqual(module.selection, [c])
        module.select(c, extending: true)
        XCTAssertEqual(module.selection, [])
    }

    func testShareAndDragURLs() throws {
        let a = try original("a.txt"), b = try original("b.txt"), c = try original("c.txt")
        let module = makeModule()
        module.start()
        module.add([a, b, c])
        try FileManager.default.removeItem(at: c)
        module.refresh()
        let ids = module.items.map(\.id)

        XCTAssertEqual(module.shareURLs.map { path($0) }, [path(a), path(b)], "nothing selected: all, missing left out")
        XCTAssertEqual(module.dragURLs(from: ids[1]).map { path($0) }, [path(b)])
        XCTAssertEqual(module.dragURLs(from: ids[2]), [], "a missing file isn't dragged")

        module.selection = [ids[1], ids[2]]
        XCTAssertEqual(module.shareURLs.map { path($0) }, [path(b)], "the selection, missing left out")
        XCTAssertEqual(module.dragURLs(from: ids[2]).map { path($0) }, [path(b)], "a selected tile drags the selection")
        XCTAssertEqual(module.dragURLs(from: ids[0]).map { path($0) }, [path(a)], "an unselected tile drags itself")
    }
}
