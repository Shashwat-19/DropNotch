import AppKit
import KeyboardShortcuts

/// Owns the AppKit side of the app: the notch panel and its screen observer (D16).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Internal so the Settings scene can reach them.
    let notchState = NotchState()
    /// A Mac without a battery gets no Battery card at all (D43).
    let registry = ModuleRegistry(modules: [HomeModule(), NowPlayingModule(source: ScriptablePlayersSource(), lyricsSource: LRCLibClient()),
                                            CalendarModule(source: EventKitCalendarSource())]
        + (PowerSourceBatterySource.hasInternalBattery ? [BatteryModule(source: PowerSourceBatterySource())] : [])
        + [WeatherModule(source: OpenMeteoClient())]
        + [NotesModule(), FileTrayModule(), ClipboardModule(),
            TerminalModule { fontSize, scrollback in SwiftTermSession(fontSize: fontSize, scrollback: scrollback) }])
    /// Rounded bottom corners on the notched display (D52). Internal so the Settings scene can reach it.
    let screenCorners = ScreenCornersController()
    /// The HUD when the Mac is plugged in (D52); nil without a battery, like the Battery card (D43).
    lazy var chargingAlert: ChargingAlert? = PowerSourceBatterySource.hasInternalBattery
        ? ChargingAlert(source: PowerSourceBatterySource(), registry: registry) : nil
    /// The HUD when headphones connect (D54); off until turned on in Settings.
    lazy var headphoneAlert = HeadphoneAlert(source: IOBluetoothHeadphoneSource(), registry: registry)
    /// Now Playing above the lock screen (D55); off until turned on in Settings.
    lazy var lockScreenPlayer: LockScreenPlayer? = registry.modules.lazy.compactMap { $0 as? NowPlayingModule }.first
        .map { LockScreenPlayer(nowPlaying: $0) }
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
            // Before any module writes there (D47).
            PrivateFolder.secureApplicationSupport()
            TerminalNotice.enforce(on: registry)
            registry.start()
            chargingAlert?.refresh()
            headphoneAlert.refresh()
            lockScreenPlayer?.refresh()
            // Inherits the main actor. The stream ends only with the app.
            Task { [notchState] in
                for await _ in KeyboardShortcuts.events(.keyDown, for: .toggleNotch) {
                    notchState.send(.hotkeyPressed)
                }
            }
        }
        followTabCount()
        notchState.screensChanged()
        followCompactContent()
        // A test run shows no windows of its own beyond the panel.
        if !Self.isTestHost { screenCorners.refresh() }
        screenObserver = ScreenObserver { [notchState, screenCorners] in
            notchState.screensChanged()
            if !Self.isTestHost { screenCorners.refresh() }
        }
    }

    /// Widens the closed notch on each side where a module fills a compact slot (D28, D36). Observation reports one change and
    /// then has to be asked again; `onChange` runs before the new value is stored, so re-read on the next turn.
    private func followCompactContent() {
        let wings = withObservationTracking { registry.compactWings } onChange: { [weak self] in
            Task { @MainActor in self?.followCompactContent() }
        }
        notchState.setWings(wings)
    }

    /// Widens the open notch while more tabs are on than the row's minimum fits (D45 Q5), the same way as above.
    private func followTabCount() {
        let items = withObservationTracking { registry.expandedModules.count + 1 } onChange: { [weak self] in
            Task { @MainActor in self?.followTabCount() }
        }
        notchState.setTopRowItems(items)
    }

    func applicationWillTerminate(_ notification: Notification) {
        registry.stop()
        chargingAlert?.stop()
        headphoneAlert.stop()
        lockScreenPlayer?.stop()
    }
}

extension KeyboardShortcuts.Name {
    /// Opens and closes the notch with keyboard focus (D30). ⌃⌥N: N for notch; not a macOS default.
    static let toggleNotch = Self("toggleNotch", initial: .init(.n, modifiers: [.control, .option]))
}
