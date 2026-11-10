import XCTest
@testable import DropNotch

final class NotchHoverStateMachineTests: XCTestCase {
    private typealias Machine = NotchHoverStateMachine

    /// Drives the machine through the given events and returns it.
    private func driven(_ events: [Machine.Event]) -> Machine {
        var machine = Machine()
        for event in events { _ = machine.handle(event) }
        return machine
    }

    private var opened: Machine { driven([.pointerEntered, .openDelayElapsed]) }

    func testStartsClosedWithPointerOutside() {
        let machine = Machine()
        XCTAssertEqual(machine.phase, .closed)
        XCTAssertFalse(machine.pointerInside)
    }

    func testEnterPeeksThenOpensAfterOpenDelay() {
        var machine = Machine()
        XCTAssertEqual(machine.handle(.pointerEntered), .startOpenDelay)
        XCTAssertEqual(machine.phase, .peek)
        XCTAssertTrue(machine.pointerInside)

        XCTAssertNil(machine.handle(.openDelayElapsed))
        XCTAssertEqual(machine.phase, .open)
    }

    func testPassingThroughNeverOpens() {
        var machine = Machine()
        XCTAssertEqual(machine.handle(.pointerEntered), .startOpenDelay)
        XCTAssertEqual(machine.phase, .peek)

        XCTAssertEqual(machine.handle(.pointerExited), .startExitDebounce)
        XCTAssertEqual(machine.phase, .peek)
        XCTAssertFalse(machine.pointerInside)

        // Closing from peek cancels the open delay, which is still running.
        XCTAssertEqual(machine.handle(.exitDebounceElapsed), .cancelOpenDelay)
        XCTAssertEqual(machine.phase, .closed)
    }

    func testOpenClosesAfterExitDebounce() {
        var machine = opened
        XCTAssertEqual(machine.handle(.pointerExited), .startExitDebounce)
        XCTAssertEqual(machine.phase, .open)

        XCTAssertNil(machine.handle(.exitDebounceElapsed))
        XCTAssertEqual(machine.phase, .closed)
    }

    func testReenteringOpenBeforeDebounceStaysOpen() {
        var machine = opened
        XCTAssertEqual(machine.handle(.pointerExited), .startExitDebounce)
        XCTAssertEqual(machine.handle(.pointerEntered), .cancelExitDebounce)
        XCTAssertEqual(machine.phase, .open)
        XCTAssertTrue(machine.pointerInside)

        // A debounce that fired before the cancel landed must not close it.
        XCTAssertNil(machine.handle(.exitDebounceElapsed))
        XCTAssertEqual(machine.phase, .open)
    }

    // A brief exit during peek must not restart the open delay.
    func testReenteringPeekBeforeDebounceKeepsTheOpenDelayRunning() {
        var machine = driven([.pointerEntered])
        XCTAssertEqual(machine.handle(.pointerExited), .startExitDebounce)
        XCTAssertEqual(machine.handle(.pointerEntered), .cancelExitDebounce)
        XCTAssertEqual(machine.phase, .peek)

        XCTAssertNil(machine.handle(.openDelayElapsed))
        XCTAssertEqual(machine.phase, .open)
    }

    func testOpenDelayEndingDuringABriefExitOpensOnReentry() {
        var machine = driven([.pointerEntered, .pointerExited])
        XCTAssertNil(machine.handle(.openDelayElapsed))
        XCTAssertEqual(machine.phase, .peek)

        XCTAssertEqual(machine.handle(.pointerEntered), .cancelExitDebounce)
        XCTAssertEqual(machine.phase, .open)
    }

    func testOpenDelayThatEndedOutsideIsForgottenOnceClosed() {
        var machine = driven([.pointerEntered, .pointerExited, .openDelayElapsed, .exitDebounceElapsed])
        XCTAssertEqual(machine.phase, .closed)

        // A fresh hover peeks and waits for a new open delay, even across a brief exit.
        XCTAssertEqual(machine.handle(.pointerEntered), .startOpenDelay)
        XCTAssertEqual(machine.handle(.pointerExited), .startExitDebounce)
        XCTAssertEqual(machine.handle(.pointerEntered), .cancelExitDebounce)
        XCTAssertEqual(machine.phase, .peek)
    }

    func testExitDebounceElapsedWhileClosedDoesNothing() {
        var machine = Machine()
        XCTAssertNil(machine.handle(.exitDebounceElapsed))
        XCTAssertEqual(machine.phase, .closed)
    }

    func testOpenDelayElapsedWhileClosedDoesNothing() {
        var machine = Machine()
        XCTAssertNil(machine.handle(.openDelayElapsed))
        XCTAssertEqual(machine.phase, .closed)
    }

    func testOpenDelayElapsedWhileOpenDoesNothing() {
        var machine = opened
        XCTAssertNil(machine.handle(.openDelayElapsed))
        XCTAssertEqual(machine.phase, .open)
    }

    func testOpenDelayElapsedInPeekWithPointerOutsideDoesNotOpen() {
        var machine = driven([.pointerEntered, .pointerExited])
        XCTAssertNil(machine.handle(.openDelayElapsed))
        XCTAssertEqual(machine.phase, .peek)
    }

    func testExitDebounceElapsedWithPointerInsideDoesNothing() {
        for start in [driven([.pointerEntered]), opened] {
            var machine = start
            let phase = machine.phase
            XCTAssertNil(machine.handle(.exitDebounceElapsed))
            XCTAssertEqual(machine.phase, phase)
        }
    }

    func testExitedWhileClosedReturnsNil() {
        var machine = Machine()
        XCTAssertNil(machine.handle(.pointerExited))
        XCTAssertEqual(machine.phase, .closed)
        XCTAssertFalse(machine.pointerInside)
    }

    // MARK: Sweep guard (D20)

    /// Moves at a steady speed: `count` events 8 ms apart (a 120 Hz pointer), starting at `x`.
    private func moves(from x: Double, at time: Double, speed: (x: Double, y: Double), count: Int)
        -> [Machine.Event] {
        (0..<count).map { step in
            let t = Double(step) * 0.008
            return .pointerMoved(x: x + speed.x * t, time: time + t)
        }
    }

    func testFastHorizontalMoveKeepsRestartingTheOpenDelay() {
        var machine = driven([.pointerEntered])
        let effects = moves(from: 800, at: 10, speed: (x: 1200, y: 0), count: 10).map { machine.handle($0) }
        // The first move only sets the baseline; every later one restarts the delay.
        XCTAssertNil(effects.first ?? nil)
        XCTAssertEqual(effects.dropFirst().filter { $0 == .startOpenDelay }.count, 9)
        XCTAssertEqual(machine.phase, .peek)
    }

    func testSlowingDownThenStoppingOpens() {
        var machine = driven([.pointerEntered])
        // Ends at x 838.4, t 10.032; the slow moves carry on from there at 200 pt/s.
        for event in moves(from: 800, at: 10, speed: (x: 1200, y: 0), count: 5) { _ = machine.handle(event) }
        let slow = moves(from: 840, at: 10.040, speed: (x: 200, y: 0), count: 5).map { machine.handle($0) }
        XCTAssertTrue(slow.allSatisfy { $0 == nil })

        XCTAssertNil(machine.handle(.openDelayElapsed))
        XCTAssertEqual(machine.phase, .open)
    }

    // Approaching the notch from below moves y only; the guard looks at x.
    func testVerticalApproachDoesNotRestartTheOpenDelay() {
        var machine = driven([.pointerEntered])
        let effects = moves(from: 855, at: 10, speed: (x: 0, y: 2000), count: 10).map { machine.handle($0) }
        XCTAssertTrue(effects.allSatisfy { $0 == nil })

        XCTAssertNil(machine.handle(.openDelayElapsed))
        XCTAssertEqual(machine.phase, .open)
    }

    func testRepeatedMoveWithTheSameTimestampIsIgnored() {
        var machine = driven([.pointerEntered, .pointerMoved(x: 800, time: 10)])
        XCTAssertNil(machine.handle(.pointerMoved(x: 900, time: 10)))
        // The baseline is still the first move: 8 pt in 8 ms = 1000 pt/s.
        XCTAssertEqual(machine.handle(.pointerMoved(x: 808, time: 10.008)), .startOpenDelay)
    }

    func testFastMovesOutsidePeekDoNothing() {
        var open = opened
        var closed = Machine()
        for event in moves(from: 800, at: 10, speed: (x: 2000, y: 0), count: 5) {
            XCTAssertNil(open.handle(event))
            XCTAssertNil(closed.handle(event))
        }
        XCTAssertEqual(open.phase, .open)
        XCTAssertEqual(closed.phase, .closed)
    }

    // The speed is never measured across a gap outside the panel.
    func testReenteringStartsANewBaseline() {
        var machine = driven([.pointerEntered, .pointerMoved(x: 700, time: 10), .pointerExited, .pointerEntered])
        XCTAssertNil(machine.handle(.pointerMoved(x: 900, time: 10.05)))
    }

    // MARK: Hotkey (D30)

    func testHotkeyFromClosedOpensWithKeyboard() {
        var machine = Machine()
        XCTAssertEqual(machine.handle(.hotkeyPressed), .cancelExitDebounce)
        XCTAssertEqual(machine.phase, .open)
        XCTAssertTrue(machine.openedByKeyboard)
    }

    func testHotkeyFromPeekOpensAndTheStaleOpenDelayDoesNothing() {
        var machine = driven([.pointerEntered])
        XCTAssertEqual(machine.handle(.hotkeyPressed), .cancelExitDebounce)
        XCTAssertEqual(machine.phase, .open)
        XCTAssertTrue(machine.openedByKeyboard)

        // The open delay started on entry is still running.
        XCTAssertNil(machine.handle(.openDelayElapsed))
        XCTAssertEqual(machine.phase, .open)
        XCTAssertTrue(machine.openedByKeyboard)
    }

    // A hover-opened notch takes focus rather than closing under the pointer.
    func testHotkeyOnAHoverOpenedNotchKeepsItOpenAndTakesFocus() {
        var machine = opened
        XCTAssertEqual(machine.handle(.hotkeyPressed), .cancelExitDebounce)
        XCTAssertEqual(machine.phase, .open)
        XCTAssertTrue(machine.openedByKeyboard)
    }

    // A click asking for focus twice must never close the notch (D31).
    func testFocusRequestedOpensWithKeyboardAndNeverCloses() {
        for start in [Machine(), driven([.pointerEntered]), opened] {
            var machine = start
            XCTAssertNil(machine.handle(.focusRequested))
            XCTAssertNil(machine.handle(.focusRequested))
            XCTAssertEqual(machine.phase, .open)
            XCTAssertTrue(machine.openedByKeyboard)
        }
    }

    func testSecondHotkeyCloses() {
        for start in [Machine(), driven([.pointerEntered]), opened] {
            var machine = start
            _ = machine.handle(.hotkeyPressed)
            XCTAssertNil(machine.handle(.hotkeyPressed))
            XCTAssertEqual(machine.phase, .closed)
            XCTAssertFalse(machine.openedByKeyboard)
        }
    }

    /// Shash (D48, D49): 1 s to come back while the notch has keyboard focus, so a typed password can't land in the
    /// app in front because the pointer drifted; hover-only opens keep 0.1 s.
    func testTheExitDelayIsLongerWithKeyboardFocus() {
        var machine = opened
        XCTAssertEqual(machine.exitDelay, .milliseconds(100))
        _ = machine.handle(.focusRequested)
        XCTAssertEqual(machine.exitDelay, .seconds(1))
        XCTAssertEqual(machine.handle(.pointerExited), .startExitDebounce)
        XCTAssertEqual(machine.handle(.pointerEntered), .cancelExitDebounce, "back in time: stays open")
        XCTAssertEqual(machine.phase, .open)
        _ = machine.handle(.pointerExited)
        _ = machine.handle(.exitDebounceElapsed)
        XCTAssertEqual(machine.phase, .closed)
        XCTAssertEqual(machine.exitDelay, .milliseconds(100), "focus cleared with the close")
        XCTAssertEqual(driven([.hotkeyPressed]).exitDelay, .seconds(1))
    }

    /// D49 revision (revises D30): the pointer leaving closes a hotkey-opened notch too, and clears its keyboard focus.
    func testPointerLeavingAHotkeyOpenedNotchClosesIt() {
        for start in [driven([.pointerEntered]), opened] {
            var machine = start
            _ = machine.handle(.hotkeyPressed)
            XCTAssertEqual(machine.handle(.pointerExited), .startExitDebounce)
            XCTAssertNil(machine.handle(.exitDebounceElapsed))
            XCTAssertEqual(machine.phase, .closed)
            XCTAssertFalse(machine.openedByKeyboard)
        }
    }

    /// D49 revision: after a click into the terminal or a note, the pointer leaving closes the notch too.
    func testPointerLeavingAfterAFocusRequestClosesIt() {
        var machine = opened
        _ = machine.handle(.focusRequested)
        XCTAssertEqual(machine.handle(.pointerExited), .startExitDebounce)
        XCTAssertNil(machine.handle(.exitDebounceElapsed))
        XCTAssertEqual(machine.phase, .closed)
        XCTAssertFalse(machine.openedByKeyboard)
    }

    /// After the pointer closed a keyboard-opened notch, the next press opens it with focus, not a press that does nothing.
    func testTheHotkeyOpensAgainAfterThePointerClosedIt() {
        var machine = opened
        _ = machine.handle(.hotkeyPressed)
        _ = machine.handle(.pointerExited)
        _ = machine.handle(.exitDebounceElapsed)
        XCTAssertEqual(machine.handle(.hotkeyPressed), .cancelExitDebounce)
        XCTAssertEqual(machine.phase, .open)
        XCTAssertTrue(machine.openedByKeyboard)
    }

    /// Back within the debounce: still open, still focused.
    func testComingBackWithinTheDebounceKeepsFocus() {
        var machine = opened
        _ = machine.handle(.hotkeyPressed)
        _ = machine.handle(.pointerExited)
        XCTAssertEqual(machine.handle(.pointerEntered), .cancelExitDebounce)
        XCTAssertNil(machine.handle(.exitDebounceElapsed))
        XCTAssertEqual(machine.phase, .open)
        XCTAssertTrue(machine.openedByKeyboard)
    }

    /// The hotkey with the pointer elsewhere: open until the pointer has come and gone, Escape or the hotkey.
    func testAHotkeyOpenWithThePointerAwayStaysOpenUntilItPassesThrough() {
        // Only a pointer exit starts the debounce, and the press cancels a pending one, so none can fire here.
        var machine = Machine()
        XCTAssertEqual(machine.handle(.hotkeyPressed), .cancelExitDebounce)
        XCTAssertNil(machine.handle(.openDelayElapsed))
        XCTAssertNil(machine.handle(.pointerMoved(x: 10, time: 1)))
        XCTAssertEqual(machine.phase, .open, "the pointer was never inside")
        _ = machine.handle(.pointerEntered)
        _ = machine.handle(.pointerExited)
        _ = machine.handle(.exitDebounceElapsed)
        XCTAssertEqual(machine.phase, .closed)
    }

    func testDismissedClosesAHotkeyOpenedNotch() {
        var machine = driven([.hotkeyPressed])
        XCTAssertNil(machine.handle(.dismissed))
        XCTAssertEqual(machine.phase, .closed)
        XCTAssertFalse(machine.openedByKeyboard)
    }

    func testDismissedClosesANotchTheHotkeyTookFromHover() {
        var machine = driven([.pointerEntered, .openDelayElapsed, .hotkeyPressed])
        XCTAssertNil(machine.handle(.dismissed))
        XCTAssertEqual(machine.phase, .closed)
        XCTAssertFalse(machine.openedByKeyboard)
    }

    // Dismissal only undoes the hotkey; hover keeps its own rules.
    func testDismissedWithoutTheHotkeyDoesNothing() {
        for start in [Machine(), driven([.pointerEntered]), opened] {
            var machine = start
            let phase = machine.phase
            XCTAssertNil(machine.handle(.dismissed))
            XCTAssertEqual(machine.phase, phase)
            XCTAssertFalse(machine.openedByKeyboard)
        }
    }

    // The pointer left a hotkey-opened notch, so an exit debounce was running when Escape closed it.
    func testStaleExitDebounceAfterDismissDoesNothing() {
        var machine = driven([.hotkeyPressed, .pointerEntered, .pointerExited, .dismissed])
        XCTAssertNil(machine.handle(.exitDebounceElapsed))
        XCTAssertEqual(machine.phase, .closed)
        XCTAssertFalse(machine.openedByKeyboard)
    }

    func testHotkeyCloseForgetsAnOpenDelayThatEndedOutside() {
        var machine = driven([.pointerEntered, .pointerExited, .openDelayElapsed, .hotkeyPressed, .hotkeyPressed])
        XCTAssertEqual(machine.phase, .closed)

        // Same as after a hover close: a fresh hover peeks and waits for a new open delay.
        XCTAssertEqual(machine.handle(.pointerEntered), .startOpenDelay)
        XCTAssertEqual(machine.phase, .peek)
        XCTAssertEqual(machine.handle(.pointerExited), .startExitDebounce)
        XCTAssertEqual(machine.handle(.pointerEntered), .cancelExitDebounce)
        XCTAssertEqual(machine.phase, .peek)
    }

    func testTimingConstants() {
        XCTAssertEqual(Machine.openDelay, .milliseconds(120))
        XCTAssertEqual(Machine.exitDebounce, .milliseconds(100))
        XCTAssertEqual(Machine.sweepSpeed, 600)
    }
}
