import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The tray in the open notch: a row of files and the actions for them (D32).
struct FileTrayExpandedView: View {
    let module: FileTrayModule

    var body: some View {
        VStack(spacing: 4) {
            if module.loadFailed {
                message("Couldn't open the tray file")
            } else if module.items.isEmpty {
                message("Drop files here")
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 4) {
                        ForEach(module.items) { tile($0) }
                    }
                }
                .scrollIndicators(.never)
                actions
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        // The open content is inserted each time the notch opens (D19), so files moved or deleted meanwhile
        // show up as moved or missing.
        .onAppear { module.refresh() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(module.title))
    }

    private func message(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tile(_ item: TrayItem) -> some View {
        let url = module.locations[item.id]
        let selected = module.selection.contains(item.id)
        // Verbatim: file names are never looked up for translation.
        let name = url?.lastPathComponent ?? item.name
        return VStack(spacing: 2) {
            Image(nsImage: url.map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSWorkspace.shared.icon(for: .item))
                .resizable()
                .frame(width: 40, height: 40)
                // A missing file is greyed out and badged, so the state doesn't rest on dimming alone (L6).
                .overlay(alignment: .bottomTrailing) {
                    if url == nil { Image(systemName: "questionmark.circle.fill").foregroundStyle(.white) }
                }
            Text(name)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(width: 72)
        .padding(4)
        .opacity(url == nil ? 0.4 : 1)
        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(selected ? 0.2 : 0)))
        .overlay {
            TrayItemDragSource(urls: { module.dragURLs(from: item.id) },
                               onClick: { module.select(item.id, extending: $0) })
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(url == nil ? Text("\(name), missing") : Text(name))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { module.select(item.id, extending: true) }
    }

    private var actions: some View {
        let urls = module.shareURLs
        let airDrop = NSSharingService(named: .sendViaAirDrop)
        return HStack(spacing: 4) {
            Spacer(minLength: 0)
            Button { airDrop?.perform(withItems: urls) } label: {
                // The system's own AirDrop image; there is no public SF Symbol for it.
                Label { Text("AirDrop") } icon: { Image(nsImage: airDrop?.image ?? NSImage()).resizable().scaledToFit() }
                    .labelStyle(.iconOnly)
                    .frame(width: 28, height: 20)
                    .frame(height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(urls.isEmpty || airDrop?.canPerform(withItems: urls) != true)
            ShareLink(items: urls) { icon("Share", systemImage: "square.and.arrow.up") }
                .buttonStyle(.plain)
                .disabled(urls.isEmpty)
            action("Remove", systemImage: "minus.circle", disabled: module.selection.isEmpty) {
                module.remove(module.selection)
            }
            action("Clear All", systemImage: "trash", disabled: false) { module.clear() }
        }
        .overlay(alignment: .leading) {
            if module.saveFailed {
                Text("Couldn't save the tray")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func action(_ label: LocalizedStringKey, systemImage: String, disabled: Bool,
                        perform: @escaping () -> Void) -> some View {
        Button(action: perform) { icon(label, systemImage: systemImage) }
            .buttonStyle(.plain)
            .disabled(disabled)
    }

    /// Icon-only on screen; VoiceOver reads the label. About a 24 pt target (L7).
    private func icon(_ label: LocalizedStringKey, systemImage: String) -> some View {
        Label(label, systemImage: systemImage)
            .labelStyle(.iconOnly)
            .frame(width: 28, height: 24)
            .contentShape(Rectangle())
    }
}
