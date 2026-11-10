import SwiftUI

/// Settings › Terminal (D48): the tab, its font size and scrollback, and what commands typed there can do.
struct TerminalSettingsView: View {
    let module: TerminalModule
    let registry: ModuleRegistry

    @AppStorage(TerminalSettings.fontSizeKey) private var fontSize = TerminalSettings.defaultFontSize
    @AppStorage(TerminalSettings.scrollbackKey) private var scrollback = TerminalSettings.defaultScrollback

    var body: some View {
        Form {
            Section {
                Toggle("Terminal tab", isOn: Binding(get: { registry.enabledIDs.contains(module.id) },
                                                     set: { registry.setEnabled(module.id, $0) }))
            } footer: {
                Text("Your login shell, in your home folder. It starts when you open the tab, keeps running while the notch is closed, and ends with End Session, turning the tab off or quitting DropNotch.")
                    .foregroundStyle(.secondary)
            }
            Section {
                // Bound through the clamping helpers, so a value from an older version or `defaults write` shows as
                // the one in use.
                Picker("Font size", selection: Binding(get: { Int(TerminalSettings.fontSize(fontSize)) },
                                                       set: { fontSize = $0 })) {
                    ForEach(TerminalSettings.fontSizes, id: \.self) { Text("\($0) pt").tag($0) }
                }
                Picker("Scrollback", selection: Binding(get: { TerminalSettings.scrollback(scrollback) },
                                                        set: { scrollback = $0 })) {
                    ForEach(TerminalSettings.scrollbackChoices, id: \.self) { Text("\($0) lines").tag($0) }
                }
            } footer: {
                Text("Scrollback stays in memory and is gone when the session ends.").foregroundStyle(.secondary)
            }
            Section("Permissions") {
                Text("Commands you run in the Terminal tab use DropNotch's permissions, as they would in the terminal in VS Code or iTerm: Calendars (full access, which can change events), the Desktop, Documents and Downloads folders, and controlling other apps, wherever you've allowed them. If a command needs something else, macOS asks in DropNotch's name, and what you allow stays allowed for DropNotch.")
                Text("Your shell's setup files (such as .zshrc) and the tools they run get the same permissions, and jobs you start with nohup or disown keep running after the session ends. Programs in the terminal can't read or change your clipboard; ⌘C and ⌘V work as usual.")
            }
            .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}
