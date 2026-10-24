import AppKit

/// Owns the AppKit side of the app: the notch panel and its screen observer (D16).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchState: NotchState?
    private var screenObserver: ScreenObserver?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panel = NotchPanel(contentView: NotchHostingView(rootView: NotchRootView()))
        let notchState = NotchState(panel: panel)
        notchState.screensChanged()
        self.notchState = notchState
        screenObserver = ScreenObserver { notchState.screensChanged() }
    }
}
