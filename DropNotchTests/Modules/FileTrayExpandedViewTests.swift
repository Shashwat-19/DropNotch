import SwiftUI
import XCTest
@testable import DropNotch

final class FileTrayExpandedViewTests: XCTestCase {
    private typealias View = FileTrayExpandedView
    private let a = UUID(), b = UUID()

    func testWithoutASelectionRemoveIsSkipped() {
        XCTAssertEqual(View.focusOrder(tiles: [a, b], canShare: true, canAirDrop: true, hasSelection: false),
                       [.tile(a), .tile(b), .airDrop, .share, .clearAll])
    }

    func testWithASelectionEveryActionIsAStop() {
        XCTAssertEqual(View.focusOrder(tiles: [a, b], canShare: true, canAirDrop: true, hasSelection: true),
                       [.tile(a), .tile(b), .airDrop, .share, .remove, .clearAll])
    }

    // Nothing to share (every selected file missing): no AirDrop or Share, and AirDrop isn't even asked.
    func testWithNoShareURLsAirDropAndShareAreSkipped() {
        var asked = false
        let order = View.focusOrder(tiles: [a], canShare: false, canAirDrop: { asked = true; return true }(),
                                    hasSelection: true)
        XCTAssertEqual(order, [.tile(a), .remove, .clearAll])
        XCTAssertFalse(asked)
    }

    func testWhenAirDropCantSendOnlyShareRemains() {
        XCTAssertEqual(View.focusOrder(tiles: [a], canShare: true, canAirDrop: false, hasSelection: false),
                       [.tile(a), .share, .clearAll])
    }

    func testClearAllIsAlwaysTheLastStop() {
        XCTAssertEqual(View.focusOrder(tiles: [], canShare: false, canAirDrop: false, hasSelection: false),
                       [.clearAll])
    }

    func testArrowsStepThroughTheOrder() {
        let order = View.focusOrder(tiles: [a, b], canShare: true, canAirDrop: true, hasSelection: true)
        XCTAssertEqual(View.focus(after: .tile(b), in: order, moving: .right), .airDrop)
        XCTAssertEqual(View.focus(after: .tile(b), in: order, moving: .down), .airDrop)
        XCTAssertEqual(View.focus(after: .airDrop, in: order, moving: .left), .tile(b))
        XCTAssertEqual(View.focus(after: .airDrop, in: order, moving: .up), .tile(b))
    }

    func testArrowsStopAtEitherEnd() {
        let order = View.focusOrder(tiles: [a], canShare: true, canAirDrop: true, hasSelection: false)
        XCTAssertEqual(View.focus(after: .tile(a), in: order, moving: .left), .tile(a))
        XCTAssertEqual(View.focus(after: .clearAll, in: order, moving: .right), .clearAll)
    }

    func testFromNothingFocusedAnyArrowGoesToTheFirstStop() {
        let order = View.focusOrder(tiles: [a, b], canShare: true, canAirDrop: true, hasSelection: false)
        XCTAssertEqual(View.focus(after: nil, in: order, moving: .right), .tile(a))
        XCTAssertEqual(View.focus(after: nil, in: order, moving: .left), .tile(a))
    }

    // e.g. Remove was focused and the selection was cleared elsewhere.
    func testAStopThatIsGoneGoesToTheFirstStop() {
        let order = View.focusOrder(tiles: [a], canShare: false, canAirDrop: false, hasSelection: false)
        XCTAssertEqual(View.focus(after: .remove, in: order, moving: .right), .tile(a))
    }
}
