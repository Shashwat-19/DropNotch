import AppKit

/// Owns the AppKit side of the app: the notch panel and its screen observer (D16).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let notchState = NotchState()
    private let registry = ModuleRegistry(modules: [NowPlayingModule(source: ScriptablePlayersSource())])
    private var screenObserver: ScreenObserver?

    func applicationDidFinishLaunching(_ notification: Notification) {
        notchState.panel = NotchPanel(contentView: NotchHostingView(rootView: NotchRootView(state: notchState, registry: registry)))
        registry.start()
        notchState.screensChanged()
        screenObserver = ScreenObserver { [notchState] in notchState.screensChanged() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        registry.stop()
    }
}
