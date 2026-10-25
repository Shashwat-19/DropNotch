import XCTest
@testable import DropNotch

// Raw numbers on purpose: they are the codes D23's table documents.
final class AppleEventOutcomeTests: XCTestCase {
    func testEveryDocumentedStatus() {
        XCTAssertEqual(AppleEventOutcome(status: 0), .ok)
        XCTAssertEqual(AppleEventOutcome(status: -1743), .denied)
        XCTAssertEqual(AppleEventOutcome(status: -1744), .needsConsent)
        XCTAssertEqual(AppleEventOutcome(status: -600), .notRunning)
        XCTAssertEqual(AppleEventOutcome(status: -609), .notRunning)
        XCTAssertEqual(AppleEventOutcome(status: -1712), .timedOut)
    }

    func testAnyOtherStatusFailsWithItsCode() {
        XCTAssertEqual(AppleEventOutcome(status: -1708), .failed(-1708))
        XCTAssertEqual(AppleEventOutcome(status: 1), .failed(1))
    }
}
