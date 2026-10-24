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

    // Strong reference cycle (state → panel → hosting view → root view → state), on
    // purpose: AppDelegate keeps all of them for the app's lifetime.
    @ObservationIgnored var panel: NotchPanel?
    @ObservationIgnored private var hover = NotchHoverStateMachine()
    @ObservationIgnored private var timer: Task<Void, Never>?
    /// Bumped on every phase change and screen change, so a close animation's completion
    /// can tell whether anything happened after it started (D19).
    @ObservationIgnored private var changeCount = 0

    private static let spring = Animation.spring(duration: 0.35, bounce: 0.15)

    /// Re-reads the screens and moves the panel. Called at launch and after each
    /// debounced screen change. Resets the hover state, because the old frames no longer
    /// apply; a pointer still inside has to leave and come back before hover works again.
    func screensChanged() {
        guard let panel else { return }
        timer?.cancel()
        changeCount += 1
        hover = NotchHoverStateMachine()
        displayedPhase = .closed

        let screens = NSScreen.screens.compactMap { screen in
            screen.displayID.map { (id: $0, screen: screen, geometry: NotchGeometry(screen: screen)) }
        }
        guard let id = ScreenObserver.chooseDisplay(screens.map { ($0.id, $0.geometry.hasNotch) }),
              let chosen = screens.first(where: { $0.id == id }) else {
            Logger.notch.debug("No display for the notch panel")
            geometry = nil
            panel.orderOut(nil)
            return
        }
        Logger.notch.debug("Notch panel on display \(id), notch: \(chosen.geometry.hasNotch)")
        geometry = chosen.geometry
        setPanelFrame(chosen.geometry.closedFrame, reason: "screen change")
        // Shows the panel without activating DropNotch.
        panel.orderFrontRegardless()
    }

    /// Called by the tracking area in `NotchHostingView` and by this class's own timer.
    func send(_ event: NotchHoverStateMachine.Event) {
        let old = hover
        let effect = hover.handle(event)
        let summary = "\(event): \(old.phase) → \(hover.phase), inside \(old.pointerInside) → \(hover.pointerInside), "
            + "effect \(effect.map { "\($0)" } ?? "none")"
        Logger.notch.debug("Hover \(summary, privacy: .public)")
        switch effect {
        case .startOpenDelay?:
            startTimer(NotchHoverStateMachine.openDelay, then: .openDelayElapsed)
        case .startExitDebounce?:
            startTimer(NotchHoverStateMachine.exitDebounce, then: .exitDebounceElapsed)
        case .cancelTimer?:
            Logger.notch.debug("Timer cancelled")
            timer?.cancel()
        case nil:
            break
        }
        show(hover.phase)
    }

    private func startTimer(_ delay: Duration, then event: NotchHoverStateMachine.Event) {
        timer?.cancel()
        let name = "\(event)"
        Logger.notch.debug("Timer started: \(name, privacy: .public) after \(delay.description, privacy: .public)")
        // One-shot, cancellable; inherits the main actor (ARCHITECTURE.md §9).
        timer = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            Logger.notch.debug("Timer fired: \(name, privacy: .public)")
            self?.send(event)
        }
    }

    /// Grow: enlarge the panel first, then animate the shape into the new space.
    /// Shrink: animate the shape first, then shrink the panel once the animation ends (D19).
    private func show(_ phase: NotchHoverStateMachine.Phase) {
        guard phase != displayedPhase, let geometry, let panel else { return }
        changeCount += 1
        let step = "\(displayedPhase) → \(phase), change \(changeCount)"
        Logger.notch.debug("Show \(step, privacy: .public)")
        let animation = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : Self.spring
        if phase == .closed {
            let started = changeCount
            withAnimation(animation) {
                displayedPhase = .closed
            } completion: { [weak self] in
                // Skip if the pointer came back or the screen changed while the shape was shrinking.
                guard let self, self.changeCount == started, let geometry = self.geometry else {
                    Logger.notch.debug("Close completion skipped (started at change \(started))")
                    return
                }
                self.setPanelFrame(geometry.closedFrame, reason: "close completion")
            }
        } else {
            let target = geometry.frame(for: phase)
            // After re-entering during a close the panel is still larger; keep it, so the
            // pointer stays inside and the shape isn't clipped mid-animation.
            if !panel.frame.contains(target) {
                setPanelFrame(target, reason: "grow")
            } else {
                Logger.notch.debug("Grow kept larger frame \(NSStringFromRect(panel.frame), privacy: .public)")
            }
            withAnimation(animation) { displayedPhase = phase }
        }
    }

    private func setPanelFrame(_ frame: CGRect, reason: String) {
        guard let panel, let geometry else { return }
        let change = "\(NSStringFromRect(panel.frame)) → \(NSStringFromRect(frame))"
        Logger.notch.debug("Panel frame (\(reason, privacy: .public)): \(change, privacy: .public)")
        // The open frame is the largest and shares every phase's top edge and centre, so
        // every phase's shape fits a canvas there.
        panel.setFrame(frame, canvas: geometry.openFrame)
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
