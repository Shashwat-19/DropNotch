import XCTest
@testable import DropNotch

@MainActor
final class NotesModuleTests: XCTestCase {
    private var directory: URL!

    /// A fresh folder per test, so nothing touches the real Application Support note.
    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appending(path: "NotesModuleTests-\(UUID())")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    /// In a subfolder that doesn't exist yet, so saving must create it.
    private var fileURL: URL { directory.appending(path: "Notes/note.txt") }

    private func makeModule(saveDelay: Duration = .milliseconds(20)) -> NotesModule {
        NotesModule(fileURL: fileURL, saveDelay: saveDelay)
    }

    private func write(_ data: Data) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL)
    }

    private func fileText() -> String? { try? String(contentsOf: fileURL, encoding: .utf8) }

    /// Polls, yielding the main actor so the save task can run. Fails after `timeout`.
    private func waitUntil(timeout: Duration = .seconds(2), _ condition: () -> Bool,
                           file: StaticString = #filePath, line: UInt = #line) async throws {
        let deadline = ContinuousClock.now + timeout
        while !condition() {
            guard ContinuousClock.now < deadline else { return XCTFail("timed out", file: file, line: line) }
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    /// For asserting that nothing happens: comfortably longer than the 20 ms save delay.
    private func waitPastSaveDelay() async throws { try await Task.sleep(for: .milliseconds(150)) }

    func testIdentity() {
        let module = makeModule()
        XCTAssertEqual(module.id, "notes")
        XCTAssertFalse(module.hasCompactContent)
    }

    func testStartWithNoFileIsEmptyAndWritesNothingUntilAnEdit() async throws {
        let module = makeModule()
        module.start()
        XCTAssertEqual(module.text, "")
        XCTAssertFalse(module.loadFailed)
        try await waitPastSaveDelay()
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path), "not even the folder is created")
        module.stop()
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path), "stop() with no edit writes nothing")
    }

    func testStartLoadsExistingNoteWithoutWritingIt() async throws {
        try write(Data("Shopping: oat milk\n".utf8))
        let past = Date(timeIntervalSince1970: 1_000_000)
        try FileManager.default.setAttributes([.modificationDate: past], ofItemAtPath: fileURL.path)
        let module = makeModule()
        module.start()
        XCTAssertEqual(module.text, "Shopping: oat milk\n")
        XCTAssertFalse(module.loadFailed)
        try await waitPastSaveDelay()
        module.stop()
        let modified = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date
        XCTAssertEqual(modified, past, "loading and stopping must not rewrite the file")
    }

    func testEditIsSavedAfterTheDelayAndCreatesTheFolder() async throws {
        let module = makeModule()
        module.start()
        module.text = "Café ☕️ naïve 日本語"
        XCTAssertNil(fileText(), "not before the delay")
        try await waitUntil { self.fileText() == "Café ☕️ naïve 日本語" }

        let reloaded = makeModule()
        reloaded.start()
        XCTAssertEqual(reloaded.text, "Café ☕️ naïve 日本語")
    }

    func testClearingASavedNoteSavesAnEmptyFile() async throws {
        try write(Data("old".utf8))
        let module = makeModule()
        module.start()
        module.text = ""
        try await waitUntil { self.fileText() == "" }
        let reloaded = makeModule()
        reloaded.start()
        XCTAssertEqual(reloaded.text, "")
        XCTAssertFalse(reloaded.loadFailed)
    }

    func testQuickEditsSaveOnlyTheFinalText() async throws {
        let module = makeModule()
        module.start()
        for text in ["a", "ab", "abc", "abcd"] { module.text = text }
        try await waitUntil { self.fileText() != nil }
        XCTAssertEqual(fileText(), "abcd")
        try await waitPastSaveDelay()
        XCTAssertEqual(fileText(), "abcd", "no stale earlier save lands later")
    }

    func testStopFlushesAnUnsavedEditAtOnce() {
        let module = makeModule(saveDelay: .seconds(60))
        module.start()
        module.text = "before quit"
        XCTAssertNil(fileText())
        module.stop()
        XCTAssertEqual(fileText(), "before quit")
    }

    func testUnreadableFileSetsLoadFailedAndIsNeverOverwritten() async throws {
        let original = Data([0x66, 0xFF, 0xFE, 0x80]) // not valid UTF-8
        try write(original)
        let module = makeModule()
        module.start()
        XCTAssertTrue(module.loadFailed)
        XCTAssertEqual(module.text, "")
        module.text = "typed anyway"
        try await waitPastSaveDelay()
        module.stop()
        XCTAssertEqual(try Data(contentsOf: fileURL), original)
    }

    func testStartAfterStopReloadsAndClearsLoadFailed() async throws {
        try write(Data([0xFF, 0xFE]))
        let module = makeModule()
        module.start()
        XCTAssertTrue(module.loadFailed)
        module.stop()

        try write(Data("fixed".utf8))
        module.start()
        XCTAssertFalse(module.loadFailed)
        XCTAssertEqual(module.text, "fixed")

        module.text = "fixed, then edited"
        try await waitUntil { self.fileText() == "fixed, then edited" }
    }

    func testStartAfterStopPicksUpAnOutsideChange() throws {
        try write(Data("one".utf8))
        let module = makeModule(saveDelay: .seconds(60))
        module.start()
        module.stop()
        try write(Data("two".utf8))
        module.start()
        XCTAssertEqual(module.text, "two")
        module.stop()
        XCTAssertEqual(fileText(), "two", "the reload is not treated as an edit")
    }
}
