/// Hover logic for the notch: closed → peek → open (ARCHITECTURE.md §4, D18).
/// A pure value type: it only decides the next phase and which timer to run, and
/// `NotchState` runs the timers. That keeps it testable without a window or a clock.
struct NotchHoverStateMachine {
    enum Phase {
        /// The shape matches the notch.
        case closed
        /// The pointer is inside and the open delay is running; the shape grows slightly.
        case peek
        case open
    }

    enum Event {
        case pointerEntered, pointerExited, openDelayElapsed, exitDebounceElapsed
    }

    /// What `NotchState` should do with its single timer. Starting one replaces
    /// whichever timer is running.
    enum Effect {
        case startOpenDelay, startExitDebounce, cancelTimer
    }

    /// Avoids opening when the pointer only passes through (ARCHITECTURE.md §9).
    static let openDelay: Duration = .milliseconds(300)
    /// Avoids flicker when the pointer grazes the edge (ARCHITECTURE.md §9).
    static let exitDebounce: Duration = .milliseconds(100)

    private(set) var phase = Phase.closed
    private(set) var pointerInside = false

    mutating func handle(_ event: Event) -> Effect? {
        switch event {
        case .pointerEntered:
            pointerInside = true
            switch phase {
            case .closed:
                phase = .peek
                return .startOpenDelay
            case .peek:
                // Back inside before the exit debounce ended, which replaced the open delay.
                return .startOpenDelay
            case .open:
                return .cancelTimer
            }
        case .pointerExited:
            pointerInside = false
            return phase == .closed ? nil : .startExitDebounce
        case .openDelayElapsed:
            if phase == .peek && pointerInside { phase = .open }
            return nil
        case .exitDebounceElapsed:
            if !pointerInside { phase = .closed }
            return nil
        }
    }
}
