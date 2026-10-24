import AppKit
import os

/// Keeps the notch panel on the chosen display (D9) at the closed size (§7).
@MainActor
final class NotchState {
    private let panel: NSPanel

    init(panel: NSPanel) {
        self.panel = panel
    }

    /// Re-reads the screens and moves the panel. Called at launch and after each
    /// debounced screen change.
    func screensChanged() {
        let screens = NSScreen.screens.compactMap { screen in
            screen.displayID.map { (id: $0, screen: screen, geometry: NotchGeometry(screen: screen)) }
        }
        guard let id = ScreenObserver.chooseDisplay(screens.map { ($0.id, $0.geometry.hasNotch) }),
              let chosen = screens.first(where: { $0.id == id }) else {
            Logger.notch.debug("No display for the notch panel")
            panel.orderOut(nil)
            return
        }
        Logger.notch.debug("Notch panel on display \(id), notch: \(chosen.geometry.hasNotch)")
        panel.setFrame(chosen.geometry.closedFrame, display: true)
        // Shows the panel without activating DropNotch.
        panel.orderFrontRegardless()
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
