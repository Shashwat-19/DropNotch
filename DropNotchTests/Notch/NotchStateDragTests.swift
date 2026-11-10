import XCTest
@testable import DropNotch

/// D49 revision: a held mouse button (a drag) holds back the pointer-exit close. Without a panel, `send` does no window work.
@MainActor
final class NotchStateDragTests: XCTestCase {
    override func tearDown() {
        NotchState.mouseButtonsDown = { NSEvent.pressedMouseButtons != 0 }
        super.tearDown()
    }

    func testTheExitCloseWaitsWhileAButtonIsHeld() {
        let state = NotchState(defaults: UserDefaults(suiteName: "NotchStateDragTests.\(UUID())")!)
        // Opened by hover, then the pointer leaves (no panel, so the timers are the only effect).
        state.send(.pointerEntered)
        state.send(.openDelayElapsed)
        state.send(.pointerExited)
        NotchState.mouseButtonsDown = { true }
        state.send(.exitDebounceElapsed)
        XCTAssertTrue(state.isOpenForTesting, "held back during a drag")
        NotchState.mouseButtonsDown = { false }
        state.send(.exitDebounceElapsed)
        XCTAssertFalse(state.isOpenForTesting, "closes once the button is up")
    }
}
