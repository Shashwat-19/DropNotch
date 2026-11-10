import XCTest
@testable import DropNotch

/// Only what runs without a panel or real screens; the screen-backed path is a device check.
@MainActor
final class NotchStateTests: XCTestCase {
    /// Before the first `screensChanged()` it only stores the count: no geometry, no panel work, no crash.
    func testSetTopRowItemsBeforeAnyScreenOnlyStoresTheCount() {
        let state = NotchState()
        state.setTopRowItems(6)
        state.setTopRowItems(6)
        state.setTopRowItems(2)
        XCTAssertNil(state.geometry)
        XCTAssertEqual(state.displayedPhase, .closed)
    }
}
