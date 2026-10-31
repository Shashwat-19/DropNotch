import AppKit
import KeyboardShortcuts

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
        let panel = NotchPanel(contentView: NotchHostingView(rootView: NotchRootView(state: notchState, registry: registry)))
        panel.onDismiss = { [notchState] in notchState.send(.dismissed) }
        notchState.panel = panel
        // A test run must never start real modules (no player permission checks or Apple Events) or take
        // the user's global shortcut.
        if !Self.isTestHost {
            registry.start()
            // Inherits the main actor. The stream ends only with the app.
            Task { [notchState] in
                for await _ in KeyboardShortcuts.events(.keyDown, for: .toggleNotch) {
                    notchState.send(.hotkeyPressed)
                }
            }
        }
        notchState.screensChanged()
        followCompactContent()
        screenObserver = ScreenObserver { [notchState] in notchState.screensChanged() }
    }

    /// Widens the closed notch while a module fills a compact slot (D28). Observation reports one change and
    /// then has to be asked again; `onChange` runs before the new value is stored, so re-read on the next turn.
    private func followCompactContent() {
        let shown = withObservationTracking { registry.hasCompactContent } onChange: { [weak self] in
            Task { @MainActor in self?.followCompactContent() }
        }
        notchState.setCompact(shown)
    }

    func applicationWillTerminate(_ notification: Notification) {
        registry.stop()
    }
}

extension KeyboardShortcuts.Name {
    /// Opens and closes the notch with keyboard focus (D30). ⌃⌥N: N for notch; not a macOS default.
    static let toggleNotch = Self("toggleNotch", initial: .init(.n, modifiers: [.control, .option]))
}
