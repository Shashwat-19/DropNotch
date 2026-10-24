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

    func testTimingConstants() {
        XCTAssertEqual(Machine.openDelay, .milliseconds(120))
        XCTAssertEqual(Machine.exitDebounce, .milliseconds(100))
    }
}
