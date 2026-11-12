import AppKit

/// Shows a `ScreenCornerWindow` at each rounded corner while Settings › General › Round the bottom corners is on (D52).
/// No timers or observers of its own: `AppDelegate` calls `refresh()` at launch and after each screen change, and
/// Settings calls it when the toggle changes.
@MainActor
final class ScreenCornersController {
    private let defaults: UserDefaults
    private(set) var windows: [ScreenCornerWindow] = []

    /// `defaults` is for tests.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isEnabled: Bool { defaults.bool(forKey: ScreenCorners.key) }

    /// Removes the corners, then puts them back on the current screens if the setting is on. `screens` is for tests.
    func refresh(screens: [(frame: CGRect, hasNotch: Bool)]? = nil) {
        windows.forEach { $0.orderOut(nil) }
        windows = []
        guard isEnabled else { return }
        let current = screens ?? NSScreen.screens.map { ($0.frame, $0.safeAreaInsets.top > 0) }
        windows = ScreenCorners.frames(screens: current).map { ScreenCornerWindow(corner: $0.corner, frame: $0.frame) }
        // Shown without activating DropNotch, as the notch panel is.
        windows.forEach { $0.orderFrontRegardless() }
    }
}
