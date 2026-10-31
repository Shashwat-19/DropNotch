/// Hover logic for the notch: closed → peek → open (ARCHITECTURE.md §4, D18), plus the hotkey (D30).
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
        /// The global shortcut: opens the notch with keyboard focus, or closes a notch it opened (D30).
        case hotkeyPressed
        /// Escape, or the panel lost keyboard focus. Closes only a notch the hotkey opened (D30).
        case dismissed
        /// A click in a hover-opened note (D31): takes keyboard focus and, unlike the hotkey, never closes.
        case focusRequested
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
    /// Opened by the hotkey: the panel holds keyboard focus and the pointer leaving doesn't close it (D30).
    private(set) var openedByKeyboard = false
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
        case .hotkeyPressed:
            // A hover-opened notch takes focus rather than closing under the pointer.
            openedByKeyboard.toggle()
            phase = openedByKeyboard ? .open : .closed
            openDue = false
            return nil
        case .focusRequested:
            openedByKeyboard = true
            phase = .open
            openDue = false
            return nil
        case .dismissed:
            guard openedByKeyboard else { return nil }
            openedByKeyboard = false
            phase = .closed
            return nil
        case .exitDebounceElapsed:
            guard !pointerInside, !openedByKeyboard, phase != .closed else { return nil }
            let wasPeek = phase == .peek
            phase = .closed
            openDue = false
            return wasPeek ? .cancelOpenDelay : nil
        }
    }
}
