import SwiftUI

/// Turn modules on and off, order their tabs and fill the compact slots (D8, D21, D34).
struct ModulesSettingsView: View {
    @Bindable var registry: ModuleRegistry
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Form {
            Section {
                ForEach(Array(registry.tabOrder.enumerated()), id: \.element) { index, id in
                    if let module = registry.modules.first(where: { $0.id == id }) {
                        row(module, index: index)
                    }
                }
            } header: {
                Text("Tabs")
            } footer: {
                Text("In the open notch, ⌘1 opens the first module that's on, ⌘2 the next, and so on. Modules that are off move to the bottom.").foregroundStyle(.secondary)
            }
            Section {
                slotPicker("Left of the notch", selection: $registry.compactLeftID)
                slotPicker("Right of the notch", selection: $registry.compactRightID)
            } header: {
                Text("Closed notch")
            } footer: {
                Text("The closed notch widens on each side that has something to show.").foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    /// Modules that are off sit at the bottom, greyed, and can't be moved until they are on again (D36).
    private func row(_ module: any NotchModule, index: Int) -> some View {
        let isOn = registry.enabledIDs.contains(module.id)
        let onCount = registry.tabOrder.filter(registry.enabledIDs.contains).count
        return HStack {
            Toggle(isOn: Binding(get: { isOn }, set: { on in withAnimation(reduceMotion ? nil : .default) { registry.setEnabled(module.id, on) } })) {
                Label { Text(module.title) } icon: { Image(systemName: module.systemImage) }
                    .foregroundStyle(isOn ? .primary : .secondary)
            }
            Spacer()
            // Buttons rather than drag to reorder, so the order can be changed by keyboard and VoiceOver.
            Button { registry.moveTab(module.id, by: -1) } label: { Image(systemName: "chevron.up") }
                .disabled(!isOn || index == 0)
                .accessibilityLabel(Text("Move \(Text(module.title)) up"))
            Button { registry.moveTab(module.id, by: 1) } label: { Image(systemName: "chevron.down") }
                .disabled(!isOn || index >= onCount - 1)
                .accessibilityLabel(Text("Move \(Text(module.title)) down"))
        }
        .buttonStyle(.borderless)
    }

    private func slotPicker(_ title: LocalizedStringKey, selection: Binding<String?>) -> some View {
        Picker(title, selection: selection) {
            Text("Nothing").tag(String?.none)
            ForEach(registry.modules.filter(\.hasCompactView), id: \.id) { module in
                Text(module.title).tag(Optional(module.id))
            }
        }
    }
}
