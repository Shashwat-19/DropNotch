import SwiftUI

/// The Settings window, opened from the menu-bar item (D14, D34): one tab per area.
struct SettingsView: View {
    let registry: ModuleRegistry
    let notchState: NotchState
    let screenCorners: ScreenCornersController
    let chargingAlert: ChargingAlert?
    let headphoneAlert: HeadphoneAlert

    var body: some View {
        TabView {
            GeneralSettingsView(notchState: notchState, screenCorners: screenCorners, chargingAlert: chargingAlert,
                                headphoneAlert: headphoneAlert)
                .tabItem { Label("General", systemImage: "gearshape") }
            ModulesSettingsView(registry: registry)
                .tabItem { Label("Modules", systemImage: "square.grid.2x2") }
            if let weather = registry.modules.lazy.compactMap({ $0 as? WeatherModule }).first {
                WeatherSettingsView(module: weather, registry: registry)
                    .tabItem { Label("Weather", systemImage: "cloud.sun") }
            }
            if let terminal = registry.modules.lazy.compactMap({ $0 as? TerminalModule }).first {
                TerminalSettingsView(module: terminal, registry: registry)
                    .tabItem { Label("Terminal", systemImage: "apple.terminal") }
            }
            PrivacySettingsView(registry: registry)
                .tabItem { Label("Privacy", systemImage: "hand.raised") }
            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 460)
    }
}
