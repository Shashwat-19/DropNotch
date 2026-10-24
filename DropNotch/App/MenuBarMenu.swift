import SwiftUI

/// Items in the menu-bar menu. A separate view because `openSettings` is only
/// available from a view's environment, not from the `App` body.
struct MenuBarMenu: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Settings…") {
            // An agent app is never active, so without this the Settings window
            // can open behind the frontmost app (D14).
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit DropNotch") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
