import AppKit

/// Owns the AppKit side of the app: the notch panel and its screen observer (D16).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let notchState = NotchState()
    private let registry = ModuleRegistry(modules: [NowPlayingModule(source: ScriptablePlayersSource())])
    private var screenObserver: ScreenObserver?

    /// Unit tests run inside the app, so it launches for them too. Xcode sets this variable for the
    /// test run. Internal so a test can confirm it.
    static let isTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    func applicationDidFinishLaunching(_ notification: Notification) {
        notchState.panel = NotchPanel(contentView: NotchHostingView(rootView: NotchRootView(state: notchState, registry: registry)))
        // A test run must never start real modules: no player permission checks or Apple Events.
        if !Self.isTestHost { registry.start() }
        notchState.screensChanged()
        screenObserver = ScreenObserver { [notchState] in notchState.screensChanged() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        registry.stop()
    }
}
