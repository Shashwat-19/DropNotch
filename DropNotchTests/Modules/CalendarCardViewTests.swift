import XCTest
@testable import DropNotch

@MainActor
final class CalendarCardViewTests: XCTestCase {
    /// The Air's 86 pt card and about a 14" MacBook Pro's both fit three rows (D44).
    func testCapacityOnTheNotchedCards() {
        XCTAssertEqual(CalendarCardView.capacity(height: 86), 3)
        XCTAssertEqual(CalendarCardView.capacity(height: 80.5), 3)
    }

    func testCapacityIsAtLeastOne() {
        for height: CGFloat in [0, -20, 10, 40] {
            XCTAssertEqual(CalendarCardView.capacity(height: height), 1, "height \(height)")
        }
    }
}
