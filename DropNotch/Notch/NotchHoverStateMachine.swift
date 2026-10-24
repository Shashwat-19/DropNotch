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

    enum Event {
        case pointerEntered, pointerExited, openDelayElapsed, exitDebounceElapsed
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

    private(set) var phase = Phase.closed
    private(set) var pointerInside = false
    /// The open delay ran out during peek while the pointer was briefly outside.
    private var openDue = false

    mutating func handle(_ event: Event) -> Effect? {
        switch event {
        case .pointerEntered:
            pointerInside = true
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
            return phase == .closed ? nil : .startExitDebounce
        case .openDelayElapsed:
            guard phase == .peek else { return nil }
            if pointerInside { phase = .open } else { openDue = true }
            return nil
        case .exitDebounceElapsed:
            guard !pointerInside, phase != .closed else { return nil }
            let wasPeek = phase == .peek
            phase = .closed
            openDue = false
            return wasPeek ? .cancelOpenDelay : nil
        }
    }
}
