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
    /// The compact wings the shape is drawn with (D28, D36). Changes together with `displayedPhase`.
    private(set) var displayedWings: Set<CompactSlot> = []
    /// The hotkey holds the notch open and the panel is key (D30). The open content moves focus to its controls.
    private(set) var hasKeyboardFocus = false
    /// Settings › General › Notch size (D49), read once at launch and changed only through `setNotchSize`.
    private(set) var notchSize: NotchSize

    @ObservationIgnored private let defaults: UserDefaults

    /// `defaults` is for tests.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        notchSize = NotchSize.saved(defaults)
    }

    // Strong reference cycle (state → panel → hosting view → root view → state), on
    // purpose: AppDelegate keeps all of them for the app's lifetime.
    @ObservationIgnored var panel: NotchPanel?
    @ObservationIgnored private var hover = NotchHoverStateMachine()
    /// One timer per kind, keyed by the event it delivers (open delay, exit debounce).
    @ObservationIgnored private var timers: [NotchHoverStateMachine.Event: Task<Void, Never>] = [:]
    /// Bumped on every phase, compact, screen and size change, so a close animation's completion
    /// can tell whether anything happened after it started (D19).
    @ObservationIgnored private var changeCount = 0
    /// What the registry last reported; `displayedWings` follows it through `show` (D28).
    @ObservationIgnored private var wantedWings: Set<CompactSlot> = []
    /// The tabs that are on plus Settings, which sets how wide the open shape is (D45).
    @ObservationIgnored private var topRowItems = NotchGeometry.topRowMinItems

    /// Re-reads the screens and moves the panel. Called at launch and after each
    /// debounced screen change. Resets the hover state, because the old frames no longer
    /// apply; a pointer still inside has to leave and come back before hover works again.
    func screensChanged() {
        guard let panel else { return }
        timers.values.forEach { $0.cancel() }
        changeCount += 1
        hover = NotchHoverStateMachine()
        displayedPhase = .closed
        displayedWings = wantedWings
        syncKeyFocus()

        guard let chosen = chosenDisplay() else {
            Logger.notch.debug("No display for the notch panel")
            geometry = nil
            panel.orderOut(nil)
            return
        }
        Logger.notch.debug("Notch panel on display \(chosen.id), notch: \(chosen.geometry.hasNotch)")
        geometry = chosen.geometry
        setPanelFrame(chosen.geometry.panelFrame(for: .closed, wings: wantedWings), reason: "screen change")
        // Shows the panel without activating DropNotch.
        panel.orderFrontRegardless()
    }

    /// Settings › General › Notch size (D49): saved, then the shape is measured again where it is, so an open notch
    /// stays open and redraws at the new size. Unlike a screen change, the hover state is kept.
    func setNotchSize(_ size: NotchSize) {
        guard size != notchSize else { return }
        notchSize = size
        defaults.set(size.rawValue, forKey: NotchSize.key)
        // No geometry yet (before launch finishes), or the display has gone: a full screen read instead.
        guard geometry != nil, let chosen = chosenDisplay() else {
            screensChanged()
            return
        }
        changeCount += 1
        geometry = chosen.geometry
        setPanelFrame(chosen.geometry.panelFrame(for: displayedPhase, wings: displayedWings), reason: "notch size")
    }

    /// The display the notch goes on (D9) and its geometry at the current tabs and size.
    private func chosenDisplay() -> (id: CGDirectDisplayID, geometry: NotchGeometry)? {
        let screens = NSScreen.screens.compactMap { screen in
            screen.displayID.map { (id: $0, geometry: NotchGeometry(screen: screen, topRowItems: topRowItems,
                                                                    size: notchSize)) }
        }
        guard let id = ScreenObserver.chooseDisplay(screens.map { ($0.id, $0.geometry.hasNotch) }, on: .saved) else {
            return nil
        }
        return screens.first { $0.id == id }
    }

    /// Called by the tracking area in `NotchHostingView` and by this class's own timers.
    func send(_ event: NotchHoverStateMachine.Event) {
        // A drag in progress (a tray file going out, text being selected past the edge, the seek bar) keeps the notch
        // open: while a mouse button is down the exit debounce starts again instead of closing it (D49 revision). Only then,
        // so no polling while idle (ARCHITECTURE §9).
        if event == .exitDebounceElapsed, Self.mouseButtonsDown() {
            startTimer(hover.exitDelay, then: .exitDebounceElapsed)
            return
        }
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
            startTimer(hover.exitDelay, then: .exitDebounceElapsed)
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

    /// Widens or narrows the shape when a module starts or stops filling a compact slot (D28), on that side only (D36).
    func setWings(_ wings: Set<CompactSlot>) {
        guard wings != wantedWings else { return }
        wantedWings = wings
        show(hover.phase)
    }

    /// Re-measures the open shape when a tab is turned on or off (D45). Like a screen change, it closes the notch;
    /// tabs only change in Settings. Before the first `screensChanged()` it only stores the count.
    func setTopRowItems(_ items: Int) {
        guard items != topRowItems else { return }
        topRowItems = items
        if geometry != nil { screensChanged() }
    }

    /// The hover machine's phase, for tests: `displayedPhase` only follows it once there is a panel.
    var isOpenForTesting: Bool { hover.phase == .open }

    /// Whether any mouse button is held. Tests replace it.
    static var mouseButtonsDown: () -> Bool = { NSEvent.pressedMouseButtons != 0 }

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
        let wings = wantedWings
        guard phase != displayedPhase || wings != displayedWings, let geometry, let panel else { return }
        changeCount += 1
        let step = "\(displayedPhase) → \(phase), wings \(wings), change \(changeCount)"
        Logger.notch.debug("Show \(step, privacy: .public)")
        let animation = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : NotchStyle.spring
        let target = geometry.panelFrame(for: phase, wings: wings)
        // After re-entering during a close the panel is still larger; keep it, so the
        // pointer stays inside and the shape isn't clipped mid-animation. With the wings the old and
        // new shapes can each be larger in a different direction (wider, taller, one side only), so grow
        // to both: every frame shares the top edge, and the open canvas contains them all.
        if !panel.frame.contains(target) {
            setPanelFrame(panel.frame.union(target), reason: "grow")
        } else {
            Logger.notch.debug("Grow kept larger frame \(NSStringFromRect(panel.frame), privacy: .public)")
        }
        let started = changeCount
        withAnimation(animation) {
            displayedPhase = phase
            displayedWings = wings
        } completion: { [weak self] in
            // Only the closed shape shrinks the panel; peek and open keep the larger frame.
            guard phase == .closed else { return }
            // Skip if the pointer came back or the screen changed while the shape was shrinking.
            guard let self, self.changeCount == started, let geometry = self.geometry else {
                Logger.notch.debug("Close completion skipped (started at change \(started))")
                return
            }
            self.setPanelFrame(geometry.panelFrame(for: .closed, wings: wings), reason: "close completion")
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
    init(screen: NSScreen, topRowItems: Int, size: NotchSize) {
        self.init(screenFrame: screen.frame,
                  safeAreaTop: screen.safeAreaInsets.top,
                  auxLeftWidth: screen.auxiliaryTopLeftArea?.width,
                  auxRightWidth: screen.auxiliaryTopRightArea?.width,
                  menuBarHeight: screen.frame.maxY - screen.visibleFrame.maxY,
                  backingScale: screen.backingScaleFactor, topRowItems: topRowItems, size: size)
    }
}
