import AppKit
import UniformTypeIdentifiers
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
    /// Another app copies during the next string read (security-auditor L2).
    var changesDuringRead = false
    /// "types", "string" and "data" for each read, in order.
    private(set) var reads: [String] = []
    private(set) var writes: [(type: NSPasteboard.PasteboardType, value: Any)] = []

    var types: [NSPasteboard.PasteboardType]? { reads.append("types"); return storedTypes }

    func string(forType dataType: NSPasteboard.PasteboardType) -> String? {
        reads.append("string")
        if changesDuringRead { changeCount += 1 }
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
    /// A throwaway file, so tests never touch the real saved history (security-auditor M1).
    private var storeURL: URL!
    private var defaults: UserDefaults!
    private var pasteboard: FakePasteboard!
    private var module: ClipboardModule!

    /// Fresh defaults per test, so nothing touches the real `clipboard.historyOn`.
    override func setUp() {
        super.setUp()
        suiteName = "ClipboardModuleTests-\(UUID())"
        storeURL = FileManager.default.temporaryDirectory.appending(path: "ClipboardModuleTests-\(UUID()).json")
        defaults = UserDefaults(suiteName: suiteName)
        pasteboard = FakePasteboard()
        module = ClipboardModule(pasteboard: pasteboard, defaults: defaults, storeURL: storeURL)
    }

    /// Always stop, so no timer or NSWorkspace observer from `start()` outlives the test.
    override func tearDown() {
        module.stop()
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: storeURL)
        super.tearDown()
    }

    /// History on without `start()`, so no timer exists and the test drives `tick()` itself.
    private func turnedOn(access: PasteboardAccess = .allowed) -> ClipboardModule {
        pasteboard.access = access
        module.turnOn()
        return module
    }

    /// A real PNG of `width` × `height` grey pixels.
    private static func png(width: Int = 1, height: Int = 1) -> Data {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    private static let onePixel = png()

    /// A 1×1 PNG padded with `byte` to `count` bytes (at least one byte of padding, so different bytes differ). The header
    /// must be real: the module checks it before keeping an image (M1).
    private func image(_ byte: UInt8, count: Int) -> Data {
        Self.onePixel + Data(repeating: byte, count: max(count - Self.onePixel.count, 1))
    }

    // 1. Consent first.

    func testIsOnByDefault() {
        XCTAssertTrue(module.isEnabledByDefault)
    }

    func testNothingIsReadBeforeTurnOnAndIsOnPersists() {
        XCTAssertFalse(module.isOn)
        pasteboard.copy("before")
        module.start()
        XCTAssertEqual(pasteboard.reads, [])
        XCTAssertTrue(module.items.isEmpty)

        module.turnOn()
        XCTAssertEqual(module.items.map(\.text), ["before"])
        XCTAssertTrue(ClipboardModule(pasteboard: FakePasteboard(), defaults: defaults, storeURL: storeURL).isOn)
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
        // Always Allow at launch (the fake's default when `module` was made), so it is trusted again after the deny (W1).
        module.turnOn()
        pasteboard.access = .denied
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

    /// Always Allow chosen while running may apply only after a relaunch, so it stays Ask: no background read (W1, D7c).
    func testAllowChosenAfterLaunchIsTreatedAsAskUntilRelaunch() {
        pasteboard.access = .ask
        let module = ClipboardModule(pasteboard: pasteboard, defaults: defaults, storeURL: storeURL)
        module.turnOn()
        pasteboard.access = .allowed
        pasteboard.copy("secret")
        module.tick()
        XCTAssertEqual(pasteboard.reads, [])
        XCTAssertEqual(module.access, .ask)
        XCTAssertTrue(module.needsRelaunch)
        XCTAssertTrue(module.hasUnreadChange)

        let relaunched = ClipboardModule(pasteboard: pasteboard, defaults: defaults, storeURL: storeURL)
        relaunched.tick()
        XCTAssertEqual(relaunched.items.map(\.text), ["secret"])
        XCTAssertFalse(relaunched.needsRelaunch)
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

    // Security-auditor fixes.

    func testImageThatIsNotAPNGOrTIFFIsSkipped() {
        let module = turnedOn()
        pasteboard.copy(data: [.png: Data(repeating: 7, count: 64)])
        module.tick()
        XCTAssertTrue(module.items.isEmpty)
    }

    func testImageOverPixelCapIsSkippedByHeader() {
        let big = Self.png(width: 5_001, height: 5_000)
        XCTAssertLessThan(big.count, ClipboardModule.maxImageBytes)
        XCTAssertFalse(ClipboardItem.isAcceptableImage(big))
        XCTAssertTrue(ClipboardItem.isAcceptableImage(Self.png(width: 5_000, height: 5_000)))
        let module = turnedOn()
        pasteboard.copy(data: [.png: big])
        module.tick()
        XCTAssertTrue(module.items.isEmpty)
    }

    func testTextOverLengthCapIsSkipped() {
        let module = turnedOn()
        pasteboard.copy(String(repeating: "a", count: ClipboardModule.maxTextLength + 1))
        module.tick()
        XCTAssertTrue(module.items.isEmpty)
        pasteboard.copy(String(repeating: "a", count: ClipboardModule.maxTextLength))
        module.tick()
        XCTAssertEqual(module.items.count, 1)
    }

    func testClipboardChangeDuringReadDropsTheItem() {
        let module = turnedOn()
        pasteboard.changesDuringRead = true
        pasteboard.copy("maybe a password")
        module.tick()
        XCTAssertTrue(module.items.isEmpty)
    }

    func testLegacyPasswordManagerMarkersAreSkipped() {
        let module = turnedOn()
        for marker in ["com.agilebits.onepassword", "de.petermaurer.TransientPasteboardType", "net.antelle.keeweb"] {
            pasteboard.copy("secret", extraTypes: [.init(marker)])
            module.tick()
        }
        XCTAssertTrue(module.items.isEmpty)
    }

    func testClearEmptiesHistoryAndKeepsWatching() {
        let module = turnedOn()
        pasteboard.copy("one")
        module.tick()
        module.clear()
        XCTAssertTrue(module.items.isEmpty)
        pasteboard.copy("two")
        module.tick()
        XCTAssertEqual(module.items.map(\.text), ["two"])
    }

    // MARK: Saved history (D34). Always `storeURL`, never the default path.

    /// History on, running and saving to disk: the state in which `add` writes the file.
    private func savingModule() -> ClipboardModule {
        module.turnOn()
        module.start()
        module.setSavesToDisk(true)
        return module
    }

    /// The module a relaunch would make: same defaults and file, an empty clipboard. The caller stops it.
    private func relaunched() -> ClipboardModule {
        let module = ClipboardModule(pasteboard: FakePasteboard(), defaults: defaults, storeURL: storeURL)
        module.start()
        return module
    }

    private func savedTexts() throws -> [String] {
        try JSONDecoder().decode([String].self, from: Data(contentsOf: storeURL))
    }

    private var fileExists: Bool { FileManager.default.fileExists(atPath: storeURL.path) }

    /// History and saving on, `data` already at `storeURL`, then `start()`: a launch reading an earlier file.
    private func moduleLoading(_ data: Data) throws -> ClipboardModule {
        module.turnOn()
        module.setSavesToDisk(true)
        try data.write(to: storeURL)
        module.start()
        return module
    }

    func testSavedTextAndLinksAreRestoredNewestFirst() throws {
        let module = savingModule()
        pasteboard.copy("hello")
        module.tick()
        pasteboard.copy("https://example.com/page")
        module.tick()
        XCTAssertEqual(try savedTexts(), ["https://example.com/page", "hello"])

        let restored = relaunched()
        defer { restored.stop() }
        XCTAssertEqual(restored.items.map(\.content), [.link("https://example.com/page"), .text("hello")])
    }

    func testImagesAreNeverWritten() throws {
        let module = savingModule()
        pasteboard.copy("caption")
        module.tick()
        pasteboard.copy(data: [.png: image(1, count: 8)])
        module.tick()
        XCTAssertEqual(module.items.count, 2)
        XCTAssertEqual(try savedTexts(), ["caption"])

        let restored = relaunched()
        defer { restored.stop() }
        XCTAssertEqual(restored.items.map(\.content), [.text("caption")])
    }

    func testSavedFileIsOwnerOnlyAndExcludedFromBackup() throws {
        let module = savingModule()
        pasteboard.copy("private")
        module.tick()
        let permissions = try FileManager.default.attributesOfItem(atPath: storeURL.path)[.posixPermissions] as? Int
        XCTAssertEqual(permissions, 0o600)
        XCTAssertEqual(try storeURL.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
    }

    func testTurningSavingOnWritesTheCurrentHistory() throws {
        module.turnOn()
        module.start()
        pasteboard.copy("before")
        module.tick()
        XCTAssertFalse(fileExists)
        module.setSavesToDisk(true)
        XCTAssertEqual(try savedTexts(), ["before"])
    }

    func testSetSavesToDiskFalseDeletesTheFile() {
        let module = savingModule()
        pasteboard.copy("x")
        module.tick()
        XCTAssertTrue(fileExists)
        module.setSavesToDisk(false)
        XCTAssertFalse(fileExists)
        XCTAssertFalse(ClipboardModule(pasteboard: FakePasteboard(), defaults: defaults, storeURL: storeURL).savesToDisk)
    }

    func testTurnOffDeletesTheFileAndTurnsSavingOff() {
        let module = savingModule()
        pasteboard.copy("x")
        module.tick()
        module.turnOff()
        XCTAssertFalse(fileExists)
        XCTAssertFalse(module.savesToDisk)
        XCTAssertFalse(module.isOn)
        XCTAssertTrue(module.items.isEmpty)
        // Turning history back on doesn't resume writing (security-auditor L3).
        module.turnOn()
        pasteboard.copy("y")
        module.tick()
        // Turn On reads what is on the clipboard now ("x"), as on the first turn-on.
        XCTAssertEqual(module.items.map(\.text), ["y", "x"])
        XCTAssertFalse(fileExists)
        let fresh = ClipboardModule(pasteboard: FakePasteboard(), defaults: defaults, storeURL: storeURL)
        XCTAssertFalse(fresh.savesToDisk)
    }

    func testClearDeletesTheFile() {
        let module = savingModule()
        pasteboard.copy("x")
        module.tick()
        module.clear()
        XCTAssertFalse(fileExists)
        XCTAssertTrue(module.savesToDisk, "clear keeps the setting")
    }

    func testClearDeletesAFileLeftFromAnEarlierRunWithoutStarting() throws {
        try JSONEncoder().encode(["left over"]).write(to: storeURL)
        module.clear()
        XCTAssertFalse(fileExists)
        XCTAssertEqual(pasteboard.reads, [])
    }

    func testStopKeepsTheFile() throws {
        let module = savingModule()
        pasteboard.copy("keep")
        module.tick()
        module.stop()
        XCTAssertTrue(module.items.isEmpty)
        XCTAssertEqual(try savedTexts(), ["keep"])
    }

    func testNothingIsWrittenWhileSavingIsOff() {
        module.turnOn()
        module.start()
        pasteboard.copy("x")
        module.tick()
        XCTAssertEqual(module.items.map(\.text), ["x"])
        XCTAssertFalse(fileExists)
    }

    func testNothingIsWrittenWhileNotRunning() {
        let module = turnedOn()
        module.setSavesToDisk(true)
        pasteboard.copy("x")
        module.tick()
        XCTAssertEqual(module.items.map(\.text), ["x"])
        XCTAssertFalse(fileExists)
    }

    func testNothingIsLoadedWhileSavingIsOff() throws {
        module.turnOn()
        try JSONEncoder().encode(["old"]).write(to: storeURL)
        module.start()
        XCTAssertTrue(module.items.isEmpty)
    }

    func testLoadIgnoresASymlink() throws {
        let target = FileManager.default.temporaryDirectory.appending(path: "ClipboardModuleTests-target-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: target) }
        try JSONEncoder().encode(["via link"]).write(to: target)
        module.turnOn()
        module.setSavesToDisk(true)
        try FileManager.default.createSymbolicLink(at: storeURL, withDestinationURL: target)
        module.start()
        XCTAssertTrue(module.items.isEmpty)
    }

    func testLoadIgnoresInvalidJSON() throws {
        XCTAssertTrue(try moduleLoading(Data("not json".utf8)).items.isEmpty)
    }

    func testLoadIgnoresAWrongJSONShape() throws {
        XCTAssertTrue(try moduleLoading(Data(#"{"a": 1}"#.utf8)).items.isEmpty)
    }

    func testLoadDropsBlankAndOverlongStrings() throws {
        let atCap = String(repeating: "a", count: ClipboardModule.maxTextLength)
        let texts = ["", " \n\t", "ok", atCap + "a", atCap]
        let module = try moduleLoading(JSONEncoder().encode(texts))
        XCTAssertEqual(module.items.map(\.text), ["ok", atCap])
    }

    func testLoadKeepsAtMostLimitItems() throws {
        let texts = (1...(ClipboardModule.limit + 5)).map { "item \($0)" }
        let module = try moduleLoading(JSONEncoder().encode(texts))
        XCTAssertEqual(module.items.map(\.text), Array(texts.prefix(ClipboardModule.limit)))
    }
}
