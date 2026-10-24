/// Hover logic for the notch: closed → peek → open (ARCHITECTURE.md §4, D18).
/// A pure value type: it only decides the next phase and which timer to run, and
/// `NotchState` runs the timers. That keeps it testable without a window or a clock.
struct NotchHoverStateMachine {
    enum Phase {
        /// The shape matches the notch.
        case closed
        /// The open delay is running; the shape grows so it is easier to stay inside.
        case peek
        case open
    }

    enum Event: Hashable {
        case pointerEntered, pointerExited, openDelayElapsed, exitDebounceElapsed
        /// The pointer moved inside the panel: screen x in points, event time in seconds.
        case pointerMoved(x: Double, time: Double)
    }

    /// What `NotchState` should do with its two timers, one per kind. Starting a timer
    /// replaces a running one of the same kind; the other kind keeps running.
    enum Effect {
        case startOpenDelay, cancelOpenDelay, startExitDebounce, cancelExitDebounce
    }

    /// Avoids opening when the pointer only passes through (ARCHITECTURE.md §9).
    static let openDelay: Duration = .milliseconds(120)
    /// Avoids flicker when the pointer grazes the edge (ARCHITECTURE.md §9).
    static let exitDebounce: Duration = .milliseconds(100)
    /// Horizontal speed, in points per second, above which peek counts as a sweep along
    /// the menu bar and the open delay starts again (D20).
    static let sweepSpeed: Double = 600

    private(set) var phase = Phase.closed
    private(set) var pointerInside = false
    /// The open delay ran out during peek while the pointer was briefly outside.
    private var openDue = false
    /// The previous move inside the panel, for the sweep speed. Cleared on enter and exit,
    /// so a speed is never measured across a gap.
    private var lastMove: (x: Double, time: Double)?

    mutating func handle(_ event: Event) -> Effect? {
        switch event {
        case .pointerEntered:
            pointerInside = true
            lastMove = nil
            switch phase {
            case .closed:
                phase = .peek
                return .startOpenDelay
            case .peek:
                // Back within the exit debounce: keep the open delay's progress (D18).
                if openDue { phase = .open; openDue = false }
                return .cancelExitDebounce
            case .open:
                return .cancelExitDebounce
            }
        case .pointerExited:
            pointerInside = false
            lastMove = nil
            return phase == .closed ? nil : .startExitDebounce
        case .openDelayElapsed:
            guard phase == .peek else { return nil }
            if pointerInside { phase = .open } else { openDue = true }
            return nil
        case let .pointerMoved(x, time):
            guard pointerInside else { return nil }
            let previous = lastMove
            // SwiftUI's own tracking areas can deliver the same move again; ignore repeats.
            guard previous.map({ time > $0.time }) ?? true else { return nil }
            lastMove = (x, time)
            guard phase == .peek, let previous else { return nil }
            let speed = abs(x - previous.x) / (time - previous.time)
            return speed > Self.sweepSpeed ? .startOpenDelay : nil
        case .exitDebounceElapsed:
            guard !pointerInside, phase != .closed else { return nil }
            let wasPeek = phase == .peek
            phase = .closed
            openDue = false
            return wasPeek ? .cancelOpenDelay : nil
        }
    }
}
