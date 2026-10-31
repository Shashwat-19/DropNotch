import AppKit
import XCTest
@testable import DropNotch

/// An in-memory clipboard that records every content read, so tests can assert what was (not) read (D7c).
@MainActor
private final class FakePasteboard: DropNotch.Pasteboard {
    var changeCount = 0
    var access = PasteboardAccess.allowed
    var storedTypes: [NSPasteboard.PasteboardType]?
    var storedString: String?
    var storedData: [NSPasteboard.PasteboardType: Data] = [:]
    /// "types", "string" and "data" for each read, in order.
    private(set) var reads: [String] = []
    private(set) var writes: [(type: NSPasteboard.PasteboardType, value: Any)] = []

    var types: [NSPasteboard.PasteboardType]? { reads.append("types"); return storedTypes }

    func string(forType dataType: NSPasteboard.PasteboardType) -> String? {
        reads.append("string")
        return dataType == .string ? storedString : nil
    }

    func data(forType dataType: NSPasteboard.PasteboardType) -> Data? {
        reads.append("data")
        return storedData[dataType]
    }

    func clearContents() -> Int {
        changeCount += 1
        storedTypes = []
        storedString = nil
        storedData = [:]
        return changeCount
    }

    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool {
        writes.append((dataType, string))
        storedTypes?.append(dataType)
        storedString = string
        return true
    }

    func setData(_ data: Data?, forType dataType: NSPasteboard.PasteboardType) -> Bool {
        writes.append((dataType, data as Any))
        storedTypes?.append(dataType)
        storedData[dataType] = data
        return true
    }

    /// Another app copying: a new changeCount and new contents.
    func copy(_ string: String? = nil, data: [NSPasteboard.PasteboardType: Data] = [:],
              extraTypes: [NSPasteboard.PasteboardType] = []) {
        changeCount += 1
        storedString = string
        storedData = data
        storedTypes = (string == nil ? [] : [.string]) + Array(data.keys) + extraTypes
    }

    func resetReads() { reads = [] }
}

@MainActor
final class ClipboardModuleTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var pasteboard: FakePasteboard!
    private var module: ClipboardModule!

    /// Fresh defaults per test, so nothing touches the real `clipboard.historyOn`.
    override func setUp() {
        super.setUp()
        suiteName = "ClipboardModuleTests-\(UUID())"
        defaults = UserDefaults(suiteName: suiteName)
        pasteboard = FakePasteboard()
        module = ClipboardModule(pasteboard: pasteboard, defaults: defaults)
    }

    /// Always stop, so no timer or NSWorkspace observer from `start()` outlives the test.
    override func tearDown() {
        module.stop()
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    /// History on without `start()`, so no timer exists and the test drives `tick()` itself.
    private func turnedOn(access: PasteboardAccess = .allowed) -> ClipboardModule {
        pasteboard.access = access
        module.turnOn()
        return module
    }

    private func image(_ byte: UInt8, count: Int) -> Data { Data(repeating: byte, count: count) }

    // 1. Consent first.

    func testNothingIsReadBeforeTurnOnAndIsOnPersists() {
        XCTAssertFalse(module.isOn)
        pasteboard.copy("before")
        module.start()
        XCTAssertEqual(pasteboard.reads, [])
        XCTAssertTrue(module.items.isEmpty)

        module.turnOn()
        XCTAssertEqual(module.items.map(\.text), ["before"])
        XCTAssertTrue(ClipboardModule(pasteboard: FakePasteboard(), defaults: defaults).isOn)
    }

    // 2. Always Allow.

    func testAllowedCapturesTextAndLinksAndSkipsUnchangedCount() {
        let module = turnedOn()
        pasteboard.copy("hello")
        module.tick()
        pasteboard.copy("https://example.com/page")
        module.tick()
        XCTAssertEqual(module.items.map(\.content), [.link("https://example.com/page"), .text("hello")])

        pasteboard.resetReads()
        module.tick()
        XCTAssertEqual(pasteboard.reads, [])
    }

    // 3. Ask: background reads never raise the alert (D7c).

    func testAskFlagsChangeWithoutReadingAndAddCurrentReadsOnce() {
        let module = turnedOn(access: .ask)
        pasteboard.copy("secret-ish")
        module.tick()
        XCTAssertTrue(module.hasUnreadChange)
        XCTAssertEqual(pasteboard.reads, [])
        XCTAssertTrue(module.items.isEmpty)

        module.addCurrent()
        XCTAssertEqual(pasteboard.reads, ["types", "string"])
        XCTAssertFalse(module.hasUnreadChange)
        XCTAssertEqual(module.items.map(\.text), ["secret-ish"])

        pasteboard.resetReads()
        module.tick()
        XCTAssertEqual(pasteboard.reads, [])
        XCTAssertFalse(module.hasUnreadChange)
    }

    // 4. Always Deny, then back to Always Allow.

    func testDeniedReadsNothingAndRefreshAfterAllowResumes() {
        pasteboard.access = .denied
        module.turnOn()
        module.start()
        pasteboard.copy("one")
        module.tick()
        pasteboard.copy("two")
        module.tick()
        XCTAssertEqual(pasteboard.reads, [])
        XCTAssertTrue(module.items.isEmpty)
        XCTAssertEqual(module.access, .denied)

        pasteboard.access = .allowed
        module.refresh()
        XCTAssertEqual(module.access, .allowed)
        pasteboard.copy("three")
        module.tick()
        XCTAssertEqual(module.items.map(\.text), ["three"])
    }

    // 5. Marked and file items.

    func testMarkedTypesAndFileURLsAreSkippedWithoutReadingContent() {
        let module = turnedOn()
        let skipped = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType",
                       "org.nspasteboard.AutoGeneratedType"].map { NSPasteboard.PasteboardType($0) } + [.fileURL]
        for type in skipped {
            pasteboard.copy("password", data: [.tiff: image(1, count: 8)], extraTypes: [type])
            module.tick()
        }
        XCTAssertTrue(module.items.isEmpty)
        XCTAssertEqual(Set(pasteboard.reads), ["types"])
    }

    // 6. Content choice and image caps.

    func testTextIsPreferredOverImageAndPNGOverTIFF() {
        let module = turnedOn()
        pasteboard.copy("caption", data: [.png: image(1, count: 8)])
        module.tick()
        XCTAssertEqual(module.items.first?.content, .text("caption"))

        let png = image(2, count: 8)
        pasteboard.copy(data: [.tiff: image(3, count: 8), .png: png])
        module.tick()
        XCTAssertEqual(module.items.first?.content, .image(png, .png))
    }

    func testWhitespaceOnlyTextFallsBackToImage() {
        let module = turnedOn()
        let tiff = image(4, count: 8)
        pasteboard.copy(" \n\t", data: [.tiff: tiff])
        module.tick()
        XCTAssertEqual(module.items.map(\.content), [.image(tiff, .tiff)])
    }

    func testImageOverTenMegabytesIsSkipped() {
        let module = turnedOn()
        pasteboard.copy(data: [.png: image(1, count: ClipboardModule.maxImageBytes + 1)])
        module.tick()
        XCTAssertTrue(module.items.isEmpty)

        pasteboard.copy(data: [.png: image(1, count: ClipboardModule.maxImageBytes)])
        module.tick()
        XCTAssertEqual(module.items.count, 1)
    }

    func testImagesBeyondFiftyMegabytesDropOldestImagesAndKeepText() {
        let module = turnedOn()
        pasteboard.copy("keep me")
        module.tick()
        let images = (1...6).map { image(UInt8($0), count: ClipboardModule.maxImageBytes) }
        for data in images {
            pasteboard.copy(data: [.png: data])
            module.tick()
        }
        XCTAssertEqual(module.items.map(\.content),
                       images.dropFirst().reversed().map { .image($0, .png) } + [.text("keep me")])
    }

    // 7. Cap and dedupe.

    func testHistoryKeepsTwentyFiveNewestFirst() {
        let module = turnedOn()
        for i in 1...(ClipboardModule.limit + 1) {
            pasteboard.copy("item \(i)")
            module.tick()
        }
        XCTAssertEqual(module.items.count, 25)
        XCTAssertEqual(module.items.first?.text, "item 26")
        XCTAssertEqual(module.items.last?.text, "item 2")
    }

    func testDuplicateMovesToTopInsteadOfRepeating() {
        let module = turnedOn()
        for text in ["a", "b", "a"] {
            pasteboard.copy(text)
            module.tick()
        }
        XCTAssertEqual(module.items.map(\.text), ["a", "b"])
    }

    // 8. Copying back.

    func testCopyTextWritesStringMovesToTopAndIsNotReadBack() {
        let module = turnedOn(access: .ask)
        pasteboard.copy("a")
        module.addCurrent()
        pasteboard.copy("b")
        module.addCurrent()
        let a = module.items[1]

        pasteboard.resetReads()
        module.copy(a)
        XCTAssertEqual(pasteboard.writes.map(\.type), [.string])
        XCTAssertEqual(pasteboard.writes.first?.value as? String, "a")
        XCTAssertEqual(module.items.map(\.id), [a.id, module.items[1].id])
        XCTAssertEqual(module.items.map(\.text), ["a", "b"])

        module.tick()
        XCTAssertEqual(pasteboard.reads, [])
        XCTAssertFalse(module.hasUnreadChange)
    }

    func testCopyImageWritesItsOwnType() {
        let module = turnedOn()
        let tiff = image(5, count: 8)
        pasteboard.copy(data: [.tiff: tiff])
        module.tick()
        pasteboard.copy("newer")
        module.tick()

        pasteboard.resetReads()
        module.copy(module.items[1])
        XCTAssertEqual(pasteboard.writes.map(\.type), [.tiff])
        XCTAssertEqual(pasteboard.writes.first?.value as? Data, tiff)
        XCTAssertEqual(module.items.first?.content, .image(tiff, .tiff))
        module.tick()
        XCTAssertEqual(pasteboard.reads, [])
    }

    // 9. Search.

    func testSearchIsCaseAndDiacriticInsensitiveAndSkipsImages() {
        let module = turnedOn()
        pasteboard.copy(data: [.png: image(1, count: 8)])
        module.tick()
        for text in ["Café Latte", "other"] {
            pasteboard.copy(text)
            module.tick()
        }
        XCTAssertEqual(module.items(matching: "cafe").map(\.text), ["Café Latte"])
        XCTAssertEqual(module.items(matching: "CAFÉ").map(\.text), ["Café Latte"])
        XCTAssertEqual(module.items(matching: "e").map(\.text), ["other", "Café Latte"])
        XCTAssertEqual(module.items(matching: "").count, 3)
        XCTAssertEqual(module.items(matching: "  ").count, 3)
    }

    // 11. Stop forgets.

    func testStopClearsHistoryAndUnreadFlag() {
        let module = turnedOn(access: .ask)
        module.start()
        pasteboard.copy("x")
        module.addCurrent()
        pasteboard.copy("y")
        module.tick()
        XCTAssertTrue(module.hasUnreadChange)

        module.stop()
        XCTAssertTrue(module.items.isEmpty)
        XCTAssertFalse(module.hasUnreadChange)
    }
}
