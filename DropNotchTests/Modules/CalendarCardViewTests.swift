import XCTest
@testable import DropNotch

@MainActor
final class CalendarCardViewTests: XCTestCase {
    /// At the 190 pt open height (D46): the Air's 126 pt card fits five rows, about a 14" MacBook Pro's four.
    func testCapacityOnTheNotchedCards() {
        XCTAssertEqual(CalendarCardView.capacity(height: 126), 5)
        XCTAssertEqual(CalendarCardView.capacity(height: 120.5), 4)
    }

    /// Header 44 (14 pt weekday over the 30 pt date) + 4 spacing, then 14 pt rows 2 pt apart: n rows from 46 + 16n.
    func testCapacityStepsExactlyWhereAnotherRowFits() {
        for rows in 2...6 {
            let height = 46 + 16 * CGFloat(rows)
            XCTAssertEqual(CalendarCardView.capacity(height: height), rows, "height \(height)")
            XCTAssertEqual(CalendarCardView.capacity(height: height - 0.5), rows - 1, "height \(height - 0.5)")
        }
    }

    func testCapacityIsOneUpToTheSecondRow() {
        XCTAssertEqual(CalendarCardView.capacity(height: 62), 1, "exactly one row")
        XCTAssertEqual(CalendarCardView.capacity(height: 77.5), 1)
        XCTAssertEqual(CalendarCardView.capacity(height: 61.5), 1, "less than one row still shows one")
    }

    func testCapacityIsAtLeastOne() {
        for height: CGFloat in [0, -20, 10, 40] {
            XCTAssertEqual(CalendarCardView.capacity(height: height), 1, "height \(height)")
        }
    }
}
