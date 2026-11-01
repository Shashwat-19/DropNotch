import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The tray in the open notch: a row of files and the actions for them (D32).
struct FileTrayExpandedView: View {
    let module: FileTrayModule
    /// Keyboard focus. Only the hotkey makes the panel key, so this stays nil while hovering (D30).
    @FocusState private var focus: Focus?
    @Environment(\.notchHasKeyboardFocus) private var hasKeyboardFocus
    @State private var shareMenu = TrayShareMenu()

    var body: some View {
        VStack(spacing: NotchStyle.tightSpacing) {
            if module.loadFailed {
                NotchEmptyState("Couldn't open the tray file", systemImage: "exclamationmark.triangle")
            } else if module.items.isEmpty {
                NotchEmptyState("Drag files onto the notch to keep them here", systemImage: "tray.and.arrow.down")
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: NotchStyle.tightSpacing) {
                            ForEach(module.items) { tile($0) }
                        }
                    }
                    .scrollIndicators(.never)
                    .onChange(of: focus) { if case .tile(let id) = focus { proxy.scrollTo(id) } }
                }
                actions
                    // Set explicitly, as in Now Playing: the panel turns key before SwiftUI inserts this view (D30).
                    .onChange(of: hasKeyboardFocus, initial: true) { if hasKeyboardFocus { focus = focusOrder.first } }
            }
        }
        // The open content is inserted each time the notch opens (D19), so files moved or deleted meanwhile
        // show up as moved or missing.
        .onAppear { module.refresh() }
        .onMoveCommand(perform: moveFocus)
    }

    /// The tiles, then the actions that are enabled, in reading order (D40).
    private var focusOrder: [Focus] {
        let urls = module.shareURLs
        var order = module.items.map { Focus.tile($0.id) }
        if !urls.isEmpty, module.airDrop?.canPerform(withItems: urls) == true { order.append(.airDrop) }
        if !urls.isEmpty { order.append(.share) }
        if !module.selection.isEmpty { order.append(.remove) }
        return order + [.clearAll]
    }

    /// Arrows step through the tiles and actions and stop at either end, as in Now Playing (D30).
    private func moveFocus(_ direction: MoveCommandDirection) {
        let order = focusOrder
        guard let current = focus, let index = order.firstIndex(of: current) else {
            focus = order.first
            return
        }
        switch direction {
        case .left, .up: focus = order[max(index - 1, 0)]
        case .right, .down: focus = order[min(index + 1, order.count - 1)]
        @unknown default: break
        }
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
                // Only the icon is dimmed, so the name stays readable.
                .opacity(url == nil ? 0.4 : 1)
                // A missing file is greyed out and badged, so the state doesn't rest on dimming alone (L6). The badge
                // stays white on a dimmed tile: it shows the file's state, not the selection.
                .overlay(alignment: .bottomTrailing) {
                    if url == nil { Image(systemName: "questionmark.circle.fill").foregroundStyle(.white) }
                }
            Text(name)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(width: 72)
        .padding([.horizontal, .top], NotchStyle.tightSpacing)
        // Room for the dot inside the tile: the horizontal scroll view would clip it below.
        .padding(.bottom, NotchStyle.spacing)
        // Several tiles can be selected; each gets a dot (D39).
        .notchSelection(selected, groupHasSelection: !module.selection.isEmpty, dot: .bottom,
                        offset: CGSize(width: 0, height: -2))
        .overlay {
            TrayItemDragSource(urls: { module.dragURLs(from: item.id) },
                               onClick: { module.select(item.id, extending: $0) })
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(url == nil ? Text("\(name), missing") : Text(name))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { module.select(item.id, extending: true) }
        .id(item.id)
        // Space or Return adds or removes the focused tile, as ⌘-click does.
        .keyboardControl(Focus.tile(item.id), focus: $focus) { module.select(item.id, extending: true) }
    }

    private var actions: some View {
        let urls = module.shareURLs
        let airDrop = module.airDrop
        let enabled = focusOrder
        let sendViaAirDrop: () -> Void = { airDrop?.perform(withItems: urls) }
        return HStack(spacing: NotchStyle.tightSpacing) {
            Spacer(minLength: 0)
            Button(action: sendViaAirDrop) {
                // The system's own AirDrop image; there is no public SF Symbol for it.
                Label { Text("AirDrop") } icon: { Image(nsImage: airDrop?.image ?? NSImage()).resizable().scaledToFit() }
                    .labelStyle(.iconOnly)
                    .frame(width: 28, height: 20)
                    .frame(height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!enabled.contains(.airDrop))
            .help("AirDrop")
            .keyboardControl(Focus.airDrop, focus: $focus, action: sendViaAirDrop)
            action("Share", systemImage: "square.and.arrow.up", .share, enabled: enabled) { shareMenu.show(urls) }
                .background(TrayShareMenu.Anchor(menu: shareMenu))
            action("Remove", systemImage: "minus.circle", .remove, enabled: enabled) {
                module.remove(module.selection)
                // Remove is disabled once nothing is selected, which would leave focus nowhere.
                if focus == .remove { focus = focusOrder.first }
            }
            action("Clear All", systemImage: "trash", .clearAll, enabled: enabled) { module.clear() }
        }
        .overlay(alignment: .leading) {
            if module.saveFailed {
                Text("Couldn't save the tray")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func action(_ label: LocalizedStringKey, systemImage: String, _ id: Focus, enabled: [Focus],
                        perform: @escaping () -> Void) -> some View {
        Button(action: perform) { icon(label, systemImage: systemImage) }
            .buttonStyle(.plain)
            .disabled(!enabled.contains(id))
            .help(Text(label))
            .keyboardControl(id, focus: $focus, action: perform)
    }

    /// Icon-only on screen; VoiceOver reads the label. About a 24 pt target (L7).
    private func icon(_ label: LocalizedStringKey, systemImage: String) -> some View {
        Label(label, systemImage: systemImage)
            .labelStyle(.iconOnly)
            .frame(width: 28, height: 24)
            .contentShape(Rectangle())
    }

    private enum Focus: Hashable {
        case tile(UUID), airDrop, share, remove, clearAll
    }
}
