import SwiftUI

@main
struct DropNotchApp: App {
    // SwiftUI apps have no app delegate of their own; this adaptor creates ours,
    // which owns the AppKit notch panel (D16).
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

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
