import SwiftUI

/// Turn modules on and off, order their tabs and fill the compact slots (D8, D21, D34).
struct ModulesSettingsView: View {
    @Bindable var registry: ModuleRegistry

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
                Text("The first tab opens with ⌘1, the next with ⌘2, and so on.").foregroundStyle(.secondary)
            }
            Section("Closed notch") {
                slotPicker("Left of the notch", selection: $registry.compactLeftID)
                slotPicker("Right of the notch", selection: $registry.compactRightID)
            }
        }
        .formStyle(.grouped)
    }

    private func row(_ module: any NotchModule, index: Int) -> some View {
        HStack {
            Toggle(isOn: Binding(get: { registry.enabledIDs.contains(module.id) },
                                 set: { registry.setEnabled(module.id, $0) })) {
                Label { Text(module.title) } icon: { Image(systemName: module.systemImage) }
            }
            Spacer()
            // Buttons rather than drag to reorder, so the order can be changed by keyboard and VoiceOver.
            Button { registry.moveTab(module.id, by: -1) } label: { Image(systemName: "chevron.up") }
                .disabled(index == 0)
                .accessibilityLabel(Text("Move \(Text(module.title)) up"))
            Button { registry.moveTab(module.id, by: 1) } label: { Image(systemName: "chevron.down") }
                .disabled(index == registry.tabOrder.count - 1)
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
