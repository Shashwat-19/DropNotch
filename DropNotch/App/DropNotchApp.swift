import SwiftUI

@main
struct DropNotchApp: App {
    var body: some Scene {
        // Agent app (LSUIElement): the menu-bar item is the only always-visible UI (D14).
        MenuBarExtra("DropNotch", systemImage: "rectangle.topthird.inset.filled") {
            MenuBarMenu()
        }
        Settings {
            SettingsView()
        }
    }
}
