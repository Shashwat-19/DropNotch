import XCTest
@testable import DropNotch

// No Apple Events here: the sender's events need real players, which tests must never touch.
@MainActor
final class AppleEventSenderTests: XCTestCase {
    // `permission(ask: true)` blocks until the user answers the Automation prompt, so its queue must
    // never be the main thread, even when called from the main actor.
    func testWorkRunsOffTheMainThread() async {
        XCTAssertTrue(Thread.isMainThread)
        let ranOnMain = await AppleEventSender.run { Thread.isMainThread }
        XCTAssertFalse(ranOnMain)
    }

    // Music answers `pPos` with a non-number between tracks; that must read as unknown, not zero (D26).
    func testOnlyNumericRepliesAreNumbers() {
        XCTAssertEqual(AppleEventSender.number(NSAppleEventDescriptor(double: 70.7)), 70.7)
        XCTAssertEqual(AppleEventSender.number(NSAppleEventDescriptor(int32: 205_800)), 205_800)
        XCTAssertNil(AppleEventSender.number(NSAppleEventDescriptor(typeCode: FourCharCode(code: "msng"))))
        XCTAssertNil(AppleEventSender.number(NSAppleEventDescriptor(string: "70")))
        XCTAssertNil(AppleEventSender.number(nil))
    }

    func testArtworkSpecifierIsTheFirstArtworkOfItsContainer() throws {
        let container = NSAppleEventDescriptor.null()
        let specifier = AppleEventSender.element("cArt", index: 1, of: container)
        XCTAssertEqual(specifier.descriptorType, FourCharCode(code: "obj "))
        let record = try XCTUnwrap(specifier.coerce(toDescriptorType: FourCharCode(code: "reco")))
        XCTAssertEqual(record.forKeyword(FourCharCode(code: "want"))?.typeCodeValue, FourCharCode(code: "cArt"))
        XCTAssertEqual(record.forKeyword(FourCharCode(code: "form"))?.enumCodeValue, FourCharCode(code: "indx"))
        XCTAssertEqual(record.forKeyword(FourCharCode(code: "seld"))?.int32Value, 1)
    }
}

