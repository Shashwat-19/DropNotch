import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The tray in the open notch: a row of files and the actions for them (D32).
struct FileTrayExpandedView: View {
    let module: FileTrayModule
    /// Keyboard focus. Only the hotkey makes the panel key, so this stays nil while hovering (D30).
    @FocusState private var focus: Focus?
    @Environment(\.notchHasKeyboardFocus) private var hasKeyboardFocus
    @Environment(\.notchSize) private var size
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
        return Self.focusOrder(tiles: module.items.map(\.id), canShare: !urls.isEmpty,
                               canAirDrop: module.airDrop?.canPerform(withItems: urls) == true,
                               hasSelection: !module.selection.isEmpty)
    }

    /// Pure so it can be tested. `canAirDrop` is only asked when there is something to share.
    static func focusOrder(tiles: [UUID], canShare: Bool, canAirDrop: @autoclosure () -> Bool,
                           hasSelection: Bool) -> [Focus] {
        var order = tiles.map { Focus.tile($0) }
        if canShare, canAirDrop() { order.append(.airDrop) }
        if canShare { order.append(.share) }
        if hasSelection { order.append(.remove) }
        return order + [.clearAll]
    }

    /// Arrows step through the tiles and actions and stop at either end, as in Now Playing (D30); Tab also reaches Clear All.
    private func moveFocus(_ direction: MoveCommandDirection) {
        focus = Self.focus(after: focus, in: focusOrder, moving: direction)
    }

    /// Pure so it can be tested: nil or a stop that's gone goes to the first stop.
    static func focus(after current: Focus?, in order: [Focus], moving direction: MoveCommandDirection) -> Focus? {
        if current == .clearAll {
            // Clear All is a Tab stop only (D40): holding → can't land on it before a Space empties the tray.
            // From it, ← and ↑ go back to the last arrow stop; → and ↓ stay.
            switch direction {
            case .left, .up: return order.last { $0 != .clearAll } ?? current
            default: return current
            }
        }
        let order = order.filter { $0 != .clearAll }
        guard let current, let index = order.firstIndex(of: current) else { return order.first }
        switch direction {
        case .left, .up: return order[max(index - 1, 0)]
        case .right, .down: return order[min(index + 1, order.count - 1)]
        @unknown default: return current
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
                .frame(width: size.scaled(40), height: size.scaled(40))
                // Only the icon is dimmed, so the name stays readable.
                .opacity(url == nil ? 0.4 : 1)
                // A missing file is greyed out and badged, so the state doesn't rest on dimming alone (L6). The badge
                // stays white on a dimmed tile: it shows the file's state, not the selection.
                .overlay(alignment: .bottomTrailing) {
                    if url == nil { Image(systemName: "questionmark.circle.fill").foregroundStyle(.white) }
                }
            Text(name)
                .font(.notch(.subheadline, size))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        // 83 pt at Large (D49).
        .frame(width: size.scaled(72))
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
            .help("AirDrop")
            .keyboardControl(Focus.airDrop, focus: $focus, action: sendViaAirDrop)
            // Outermost, so it also takes the focus stop and the key press away (code-reviewer W1).
            .disabled(!enabled.contains(.airDrop))
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
                    .font(.notch(.subheadline, size))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func action(_ label: LocalizedStringKey, systemImage: String, _ id: Focus, enabled: [Focus],
                        perform: @escaping () -> Void) -> some View {
        Button(action: perform) { icon(label, systemImage: systemImage) }
            .buttonStyle(.plain)
            .help(Text(label))
            .keyboardControl(id, focus: $focus, action: perform)
            // Outermost, so it also takes the focus stop and the key press away (code-reviewer W1).
            .disabled(!enabled.contains(id))
    }

    /// Icon-only on screen; VoiceOver reads the label. About a 24 pt target (L7).
    private func icon(_ label: LocalizedStringKey, systemImage: String) -> some View {
        Label(label, systemImage: systemImage)
            .labelStyle(.iconOnly)
            .frame(width: 28, height: 24)
            .contentShape(Rectangle())
    }

    enum Focus: Hashable {
        case tile(UUID), airDrop, share, remove, clearAll
    }
}
