import AppKit
import SwiftUI
import os

/// Keeps the notch panel on the chosen display (D9) and runs the hover state
/// machine (D18). `@Observable` so `NotchRootView` redraws when the phase changes.
@MainActor
@Observable
final class NotchState {
    /// The phase the view draws. While the close animation runs it is already
    /// `.closed` but the panel keeps its larger frame until the animation ends (D19).
    private(set) var displayedPhase = NotchHoverStateMachine.Phase.closed
    private(set) var geometry: NotchGeometry?
    /// Whether the shape is drawn with the compact wings (D28). Changes together with `displayedPhase`.
    private(set) var displaysCompact = false
    /// The hotkey holds the notch open and the panel is key (D30). The open content moves focus to its controls.
    private(set) var hasKeyboardFocus = false

    // Strong reference cycle (state → panel → hosting view → root view → state), on
    // purpose: AppDelegate keeps all of them for the app's lifetime.
    @ObservationIgnored var panel: NotchPanel?
    @ObservationIgnored private var hover = NotchHoverStateMachine()
    /// One timer per kind, keyed by the event it delivers (open delay, exit debounce).
    @ObservationIgnored private var timers: [NotchHoverStateMachine.Event: Task<Void, Never>] = [:]
    /// Bumped on every phase, compact and screen change, so a close animation's completion
    /// can tell whether anything happened after it started (D19).
    @ObservationIgnored private var changeCount = 0
    /// What the registry last reported; `displaysCompact` follows it through `show` (D28).
    @ObservationIgnored private var wantsCompact = false

    // No bounce: an overshoot past the open size would be cut flat by the panel's edges.
    private static let spring = Animation.spring(duration: 0.25, bounce: 0)

    /// Re-reads the screens and moves the panel. Called at launch and after each
    /// debounced screen change. Resets the hover state, because the old frames no longer
    /// apply; a pointer still inside has to leave and come back before hover works again.
    func screensChanged() {
        guard let panel else { return }
        timers.values.forEach { $0.cancel() }
        changeCount += 1
        hover = NotchHoverStateMachine()
        displayedPhase = .closed
        displaysCompact = wantsCompact
        syncKeyFocus()

        let screens = NSScreen.screens.compactMap { screen in
            screen.displayID.map { (id: $0, screen: screen, geometry: NotchGeometry(screen: screen)) }
        }
        guard let id = ScreenObserver.chooseDisplay(screens.map { ($0.id, $0.geometry.hasNotch) }, on: .saved),
              let chosen = screens.first(where: { $0.id == id }) else {
            Logger.notch.debug("No display for the notch panel")
            geometry = nil
            panel.orderOut(nil)
            return
        }
        Logger.notch.debug("Notch panel on display \(id), notch: \(chosen.geometry.hasNotch)")
        geometry = chosen.geometry
        setPanelFrame(chosen.geometry.panelFrame(for: .closed, compact: wantsCompact), reason: "screen change")
        // Shows the panel without activating DropNotch.
        panel.orderFrontRegardless()
    }

    /// Called by the tracking area in `NotchHostingView` and by this class's own timers.
    func send(_ event: NotchHoverStateMachine.Event) {
        // With no display the panel is ordered out; taking key focus would swallow typing into an invisible window.
        if event == .hotkeyPressed || event == .focusRequested, geometry == nil { return }
        let old = hover
        let effect = hover.handle(event)
        // Moves arrive many times a second; only a sweep restarting the open delay is news.
        if case .pointerMoved = event, effect == nil { return }
        let summary = "\(event): \(old.phase) → \(hover.phase), inside \(old.pointerInside) → \(hover.pointerInside), "
            + "effect \(effect.map { "\($0)" } ?? "none")"
        Logger.notch.debug("Hover \(summary, privacy: .public)")
        switch effect {
        case .startOpenDelay?:
            startTimer(NotchHoverStateMachine.openDelay, then: .openDelayElapsed)
        case .startExitDebounce?:
            startTimer(NotchHoverStateMachine.exitDebounce, then: .exitDebounceElapsed)
        case .cancelOpenDelay?:
            cancelTimer(.openDelayElapsed)
        case .cancelExitDebounce?:
            cancelTimer(.exitDebounceElapsed)
        case nil:
            break
        }
        show(hover.phase)
        // Keep last: handing focus back calls `send` again from inside `orderOut`, so the rest must be done.
        syncKeyFocus()
    }

    /// Makes the panel key when the hotkey opens the notch, and hands focus back when it closes (D30).
    private func syncKeyFocus() {
        guard let panel, panel.acceptsKeyboard != hover.openedByKeyboard else { return }
        // Set first: giving focus back calls `onDismiss`, which sends `.dismissed` and lands here again.
        panel.acceptsKeyboard = hover.openedByKeyboard
        hasKeyboardFocus = hover.openedByKeyboard
        Logger.notch.debug("Keyboard focus \(panel.acceptsKeyboard ? "taken" : "returned", privacy: .public)")
        if panel.acceptsKeyboard {
            // Key without activating DropNotch: the panel is non-activating.
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.returnKeyFocus()
        }
    }

    /// Widens or narrows the shape when a module starts or stops filling a compact slot (D28).
    func setCompact(_ compact: Bool) {
        guard compact != wantsCompact else { return }
        wantsCompact = compact
        show(hover.phase)
    }

    private func startTimer(_ delay: Duration, then event: NotchHoverStateMachine.Event) {
        timers[event]?.cancel()
        let name = "\(event)"
        Logger.notch.debug("Timer started: \(name, privacy: .public) after \(delay.description, privacy: .public)")
        // One-shot, cancellable; inherits the main actor (ARCHITECTURE.md §9).
        timers[event] = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            Logger.notch.debug("Timer fired: \(name, privacy: .public)")
            self?.send(event)
        }
    }

    private func cancelTimer(_ event: NotchHoverStateMachine.Event) {
        Logger.notch.debug("Timer cancelled: \(String(describing: event), privacy: .public)")
        timers[event]?.cancel()
    }

    /// Grow: enlarge the panel first, then animate the shape into the new space.
    /// Shrink: animate the shape first, then shrink the panel once the animation ends (D19).
    /// The same holds for the compact wings (D28).
    private func show(_ phase: NotchHoverStateMachine.Phase) {
        let compact = wantsCompact
        guard phase != displayedPhase || compact != displaysCompact, let geometry, let panel else { return }
        changeCount += 1
        let step = "\(displayedPhase) → \(phase), compact \(compact), change \(changeCount)"
        Logger.notch.debug("Show \(step, privacy: .public)")
        let animation = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : Self.spring
        let target = geometry.panelFrame(for: phase, compact: compact)
        // After re-entering during a close the panel is still larger; keep it, so the
        // pointer stays inside and the shape isn't clipped mid-animation. With the wings the old and
        // new shapes can each be larger in a different direction (wider, taller), so grow to both:
        // every frame shares the top edge and centre, and the open canvas contains them all.
        if !panel.frame.contains(target) {
            setPanelFrame(panel.frame.union(target), reason: "grow")
        } else {
            Logger.notch.debug("Grow kept larger frame \(NSStringFromRect(panel.frame), privacy: .public)")
        }
        let started = changeCount
        withAnimation(animation) {
            displayedPhase = phase
            displaysCompact = compact
        } completion: { [weak self] in
            // Only the closed shape shrinks the panel; peek and open keep the larger frame.
            guard phase == .closed else { return }
            // Skip if the pointer came back or the screen changed while the shape was shrinking.
            guard let self, self.changeCount == started, let geometry = self.geometry else {
                Logger.notch.debug("Close completion skipped (started at change \(started))")
                return
            }
            self.setPanelFrame(geometry.panelFrame(for: .closed, compact: compact), reason: "close completion")
        }
    }

    private func setPanelFrame(_ frame: CGRect, reason: String) {
        guard let panel, let geometry else { return }
        let change = "\(NSStringFromRect(panel.frame)) → \(NSStringFromRect(frame))"
        Logger.notch.debug("Panel frame (\(reason, privacy: .public)): \(change, privacy: .public)")
        // The open frame is the largest and shares every phase's top edge and centre, so
        // every phase's shape fits a canvas there.
        panel.setFrame(frame, canvas: geometry.panelFrame(for: .open))
    }
}

private extension NSScreen {
    /// The display ID, which stays the same for a display while it's connected.
    /// Names aren't used because two identical monitors share one.
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

private extension NotchGeometry {
    init(screen: NSScreen) {
        self.init(screenFrame: screen.frame,
                  safeAreaTop: screen.safeAreaInsets.top,
                  auxLeftWidth: screen.auxiliaryTopLeftArea?.width,
                  auxRightWidth: screen.auxiliaryTopRightArea?.width,
                  menuBarHeight: screen.frame.maxY - screen.visibleFrame.maxY,
                  backingScale: screen.backingScaleFactor)
    }
}
