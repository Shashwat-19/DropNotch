import EventKit
import XCTest
@testable import DropNotch

/// Only maps EventKit's status enum: no event store is created, so nothing prompts.
final class CalendarAccessTests: XCTestCase {
    func testEachStatusMaps() {
        XCTAssertEqual(CalendarAccess(.notDetermined), .notDetermined)
        XCTAssertEqual(CalendarAccess(.fullAccess), .allowed)
        XCTAssertEqual(CalendarAccess(.restricted), .restricted)
        XCTAssertEqual(CalendarAccess(.denied), .denied)
    }

    /// Write-only access can't read events, so the card treats it as denied (D44).
    func testWriteOnlyIsDenied() {
        XCTAssertEqual(CalendarAccess(.writeOnly), .denied)
    }
}
