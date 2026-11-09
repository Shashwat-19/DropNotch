import XCTest
@testable import DropNotch

@MainActor
final class CalendarCardViewTests: XCTestCase {
    /// At the 190 pt open height (D46): the Air's 126 pt card fits five rows, about a 14" MacBook Pro's four.
    func testCapacityOnTheNotchedCards() {
        XCTAssertEqual(CalendarCardView.capacity(height: 126), 5)
        XCTAssertEqual(CalendarCardView.capacity(height: 120.5), 4)
    }

    func testCapacityIsAtLeastOne() {
        for height: CGFloat in [0, -20, 10, 40] {
            XCTAssertEqual(CalendarCardView.capacity(height: height), 1, "height \(height)")
        }
    }
}
