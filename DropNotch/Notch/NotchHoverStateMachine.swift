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
        /// The global shortcut: opens the notch with keyboard focus, or closes a notch it opened (D30). The pointer
        /// leaving still closes it (D49 revision).
        case hotkeyPressed
        /// Escape, or the panel lost keyboard focus. Closes only a notch the hotkey opened (D30).
        case dismissed
        /// A click in a hover-opened note or terminal (D31, D48): takes keyboard focus and, unlike the hotkey, never
        /// closes the notch itself. The pointer leaving still closes it (D49 revision).
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
    /// The exit debounce while the panel has keyboard focus (Shash, D48, D49): long enough to drift off and back
    /// without the rest of a typed password landing in the app in front (ARCHITECTURE.md §9).
    static let focusedExitDebounce: Duration = .seconds(1)
    /// Horizontal speed, in points per second, above which peek counts as a sweep along
    /// the menu bar and the open delay starts again (D20).
    static let sweepSpeed: Double = 600

    private(set) var phase = Phase.closed
    private(set) var pointerInside = false
    /// The panel holds keyboard focus: opened or focused by the hotkey, or a click asked for focus (D30, D31). Cleared
    /// when the notch closes, including when the pointer leaves (D49 revision).
    private(set) var openedByKeyboard = false
    /// How long the pointer must stay out before the notch closes: 1 s with keyboard focus, else 0.1 s.
    var exitDelay: Duration { openedByKeyboard ? Self.focusedExitDebounce : Self.exitDebounce }
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
            // A press just after the pointer left mustn't be undone by that exit's debounce (D49 revision).
            return openedByKeyboard ? .cancelExitDebounce : nil
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
            // The pointer leaving closes the notch however it was opened, keyboard focus included (D49 revision; revises D30,
            // D31 and D48). `NotchState` holds this event back while a mouse button is down, for drags.
            guard !pointerInside, phase != .closed else { return nil }
            let wasPeek = phase == .peek
            phase = .closed
            openDue = false
            // Otherwise the next hotkey press would toggle it off and do nothing.
            openedByKeyboard = false
            return wasPeek ? .cancelOpenDelay : nil
        }
    }
}
