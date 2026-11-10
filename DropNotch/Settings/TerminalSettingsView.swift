import SwiftUI

/// Settings › Terminal (D48): the tab, its font size and scrollback, and what commands typed there can do.
struct TerminalSettingsView: View {
    let module: TerminalModule
    let registry: ModuleRegistry

    @AppStorage(TerminalSettings.fontSizeKey) private var fontSize = TerminalSettings.defaultFontSize
    @AppStorage(TerminalSettings.scrollbackKey) private var scrollback = TerminalSettings.defaultScrollback
    @AppStorage(TerminalSettings.typeOnOpenKey) private var typeOnOpen = false
    @State private var confirmsTurnOn = false

    var body: some View {
        Form {
            Section {
                Toggle("Terminal tab", isOn: Binding(get: { registry.enabledIDs.contains(module.id) }, set: { on in
                    // The first time, only after the permissions notice is confirmed (D48).
                    if on, TerminalNotice.needsConfirmation() { confirmsTurnOn = true } else { registry.setEnabled(module.id, on) }
                }))
            } footer: {
                Text("Your login shell, in your home folder. It starts when you open the tab, keeps running while the notch is closed, and ends with End Session, turning the tab off or quitting DropNotch.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Type as soon as the notch opens", isOn: $typeOnOpen)
            } footer: {
                Text("Your keys go to the terminal whenever the notch opens on it, even if you only passed over it. A stray Return can run a command.")
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
            Section {
                // The notice's text, kept here (Shash, D48).
                TerminalNotice.message(calendars: TerminalNotice.calendars)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Programs in the terminal can't read or change your clipboard; ⌘C and ⌘V work as usual. If a command needs something DropNotch hasn't been allowed, macOS asks in DropNotch's name.")
            } header: {
                Text(TerminalNotice.title)
            }
            .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .terminalNotice(isPresented: $confirmsTurnOn) { registry.setEnabled(module.id, true) }
    }
}
