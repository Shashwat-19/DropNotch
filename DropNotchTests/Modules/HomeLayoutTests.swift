import CoreGraphics
import XCTest
@testable import DropNotch

final class HomeLayoutTests: XCTestCase {
    // The approved mock-up (docs/mockups/home-v0.2.html): 488 pt row on the Air, 8 pt gaps (D42).
    func testTheMockUpRowOnTheAir() {
        XCTAssertEqual(HomeLayout.widths([.wide, .medium, .narrow], total: 488, spacing: 8), [225, 142, 105])
    }

    func testTheMockUpRowWithoutANotch() {
        XCTAssertEqual(HomeLayout.widths([.wide, .medium, .narrow], total: 432, spacing: 8), [198, 125, 93])
    }

    func testNoCardsHaveNoWidths() {
        XCTAssertEqual(HomeLayout.widths([], total: 488, spacing: 8), [])
    }

    func testOneCardFillsTheRow() {
        for size in [HomeCardSize.wide, .medium, .narrow] {
            XCTAssertEqual(HomeLayout.widths([size], total: 488, spacing: 8), [488], "\(size)")
        }
    }

    // 480 free: 480 × 0.29 / 0.505 = 275.6 and 480 × 0.215 / 0.505 = 204.4; the last card takes the spare point.
    func testWithoutAWideCardMediumAndNarrowShareInProportion() {
        XCTAssertEqual(HomeLayout.widths([.medium, .narrow], total: 488, spacing: 8), [275, 205])
        XCTAssertEqual(HomeLayout.widths([.narrow, .medium], total: 488, spacing: 8), [204, 276])
    }

    // Every order of 1 to 3 cards, repeats included, on every whole width from the no-notch row to beyond the Air's.
    func testWidthsAreWholeAndFillTheRowExactly() {
        let sizes: [HomeCardSize] = [.wide, .medium, .narrow]
        var rows: [[HomeCardSize]] = sizes.map { [$0] }
        rows += rows.flatMap { row in sizes.map { row + [$0] } }
        rows += rows.filter { $0.count == 2 }.flatMap { row in sizes.map { row + [$0] } }
        XCTAssertEqual(rows.count, 3 + 9 + 27)
        for total in 432...600 {
            for row in rows {
                let widths = HomeLayout.widths(row, total: CGFloat(total), spacing: 8)
                XCTAssertEqual(widths.count, row.count)
                XCTAssertEqual(widths.reduce(0, +) + 8 * CGFloat(row.count - 1), CGFloat(total), "\(row) on \(total)")
                XCTAssertTrue(widths.allSatisfy { $0 == $0.rounded() && $0 > 0 }, "\(row) on \(total): \(widths)")
            }
        }
    }
}
