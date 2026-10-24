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

    @ObservationIgnored var panel: NSPanel?
    @ObservationIgnored private var hover = NotchHoverStateMachine()
    @ObservationIgnored private var timer: Task<Void, Never>?

    private static let spring = Animation.spring(duration: 0.35, bounce: 0.15)

    /// Re-reads the screens and moves the panel. Called at launch and after each
    /// debounced screen change. Resets the hover state, because the old frames no longer apply.
    func screensChanged() {
        guard let panel else { return }
        timer?.cancel()
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
        panel.setFrame(chosen.geometry.closedFrame, display: true)
        // Shows the panel without activating DropNotch.
        panel.orderFrontRegardless()
    }

    /// Called by the tracking area in `NotchHostingView` and by this class's own timer.
    func send(_ event: NotchHoverStateMachine.Event) {
        switch hover.handle(event) {
        case .startOpenDelay?:
            startTimer(NotchHoverStateMachine.openDelay, then: .openDelayElapsed)
        case .startExitDebounce?:
            startTimer(NotchHoverStateMachine.exitDebounce, then: .exitDebounceElapsed)
        case .cancelTimer?:
            timer?.cancel()
        case nil:
            break
        }
        show(hover.phase)
    }

    private func startTimer(_ delay: Duration, then event: NotchHoverStateMachine.Event) {
        timer?.cancel()
        // One-shot, cancellable; inherits the main actor (ARCHITECTURE.md §9).
        timer = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.send(event)
        }
    }

    /// Grow: enlarge the panel first, then animate the shape into the new space.
    /// Shrink: animate the shape first, then shrink the panel once the animation ends (D19).
    private func show(_ phase: NotchHoverStateMachine.Phase) {
        guard phase != displayedPhase, let geometry, let panel else { return }
        let animation = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : Self.spring
        if phase == .closed {
            withAnimation(animation) {
                displayedPhase = .closed
            } completion: { [weak self] in
                // The pointer may have come back while the shape was shrinking.
                guard let self, self.hover.phase == .closed else { return }
                panel.setFrame(geometry.closedFrame, display: true)
            }
        } else {
            panel.setFrame(geometry.frame(for: phase), display: true)
            withAnimation(animation) { displayedPhase = phase }
        }
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
