import SwiftUI

/// Clipboard history in the open notch (D7c): the turn-on step, the macOS access states, then search and the items.
/// Click a row, or Return on the highlighted one, to copy it back.
struct ClipboardExpandedView: View {
    let module: ClipboardModule
    @State private var query = ""
    /// The row Return copies; ↑ and ↓ in the search field move it.
    @State private var highlighted = 0
    /// Keyboard focus: Search, or one of the buttons (D40). Only the hotkey or a click in Search makes the panel key.
    @FocusState private var focus: Focus?
    @Environment(\.notchHasKeyboardFocus) private var hasKeyboardFocus
    @Environment(\.requestNotchKeyboardFocus) private var requestKeyboardFocus
    @Environment(\.dismissNotch) private var dismissNotch

    private var shown: [ClipboardItem] { module.items(matching: query) }

    var body: some View {
        VStack(alignment: .leading, spacing: NotchStyle.tightSpacing) {
            if !module.isOn {
                NotchEmptyState("Keep the last 25 things you copy, on this Mac only. macOS may ask whether DropNotch can paste from other apps.",
                                systemImage: "doc.on.clipboard") {
                    Button("Turn On Clipboard History") { module.turnOn() }
                        .keyboardControl(Focus.turnOn, focus: $focus) { module.turnOn() }
                        .onChange(of: hasKeyboardFocus, initial: true) { if hasKeyboardFocus { focus = .turnOn } }
                }
            } else if module.access == .denied {
                NotchEmptyState("Clipboard access is blocked in System Settings › Privacy & Security › Paste from Other Apps.",
                                systemImage: "hand.raised")
            } else {
                if module.needsRelaunch {
                    message("Always Allow applies after you quit and reopen DropNotch. Until then, macOS asks before each read.")
                } else if module.access == .ask {
                    message("macOS asks before each read. To keep history automatically, choose Always Allow in Privacy & Security › Paste from Other Apps.")
                }
                HStack(spacing: NotchStyle.spacing) {
                    searchField
                    // Tab from Search reaches these; ← and → stay with the text in Search.
                    if module.access == .ask, module.hasUnreadChange {
                        Button("Add Clipboard") { module.addCurrent() }
                            .keyboardControl(Focus.addClipboard, focus: $focus) { module.addCurrent() }
                    }
                    if !module.items.isEmpty {
                        Button("Clear") { clear() }
                            .keyboardControl(Focus.clear, focus: $focus) { clear() }
                    }
                }
                list
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { module.refresh() }
    }

    private func message(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var searchField: some View {
        TextField("Search", text: $query)
            .textFieldStyle(.roundedBorder)
            .focused($focus, equals: .search)
            .onKeyPress(.downArrow) {
                highlighted = min(highlighted + 1, max(shown.count - 1, 0))
                return .handled
            }
            .onKeyPress(.upArrow) {
                highlighted = max(highlighted - 1, 0)
                return .handled
            }
            .onSubmit { if shown.indices.contains(highlighted) { copy(shown[highlighted]) } }
            .onChange(of: query) { highlighted = 0 }
            // As in Notes (D31): a click in a hover-opened notch takes keyboard focus rather than typing into nothing.
            .overlay {
                if !hasKeyboardFocus {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { requestKeyboardFocus() }
                        .accessibilityHidden(true)
                }
            }
            // Set explicitly, as in Now Playing: the panel turns key before SwiftUI inserts this view (D30).
            .onChange(of: hasKeyboardFocus, initial: true) { if hasKeyboardFocus { focus = .search } }
    }

    @ViewBuilder private var list: some View {
        let shown = shown
        if module.items.isEmpty {
            NotchEmptyState("Nothing copied yet", systemImage: "doc.on.clipboard")
        } else if shown.isEmpty {
            NotchEmptyState("No matches", systemImage: "magnifyingglass")
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(shown.enumerated()), id: \.element.id) { index, item in
                            row(item, isHighlighted: hasKeyboardFocus && index == highlighted)
                        }
                    }
                }
                .scrollIndicators(.never)
                .onChange(of: highlighted) {
                    if shown.indices.contains(highlighted) { proxy.scrollTo(shown[highlighted].id) }
                }
            }
        }
    }

    private func row(_ item: ClipboardItem, isHighlighted: Bool) -> some View {
        Button { copy(item) } label: {
            HStack(spacing: 8) {
                if item.text == nil {
                    Group {
                        if let thumbnail = item.thumbnail {
                            Image(nsImage: thumbnail).resizable().scaledToFit()
                        } else {
                            Image(systemName: "photo")
                        }
                    }
                    .frame(width: 32, height: 20)
                    Text("Image")
                } else {
                    Image(systemName: item.isLink ? "link" : "doc.text")
                        .frame(width: 32)
                    // Verbatim: copied text is never looked up for translation.
                    Text(verbatim: item.preview)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 0)
            }
            .frame(height: 24)
            .padding(.horizontal, 6)
            // A dot in the leading padding (D39). Only a keyboard-opened notch highlights a row, so only then do the
            // others dim; a hover-opened list stays white.
            .notchSelection(isHighlighted, groupHasSelection: hasKeyboardFocus, dot: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // The search field owns the keys (↑, ↓, Return), so rows aren't Tab stops.
        .focusable(false)
        .id(item.id)
        .accessibilityHint(Text("Copies to the clipboard"))
        .accessibilityAddTraits(isHighlighted ? .isSelected : [])
    }

    /// Copies, then closes a notch that has keyboard focus (hotkey, or a click in the search field), so ⌘V goes to the
    /// app in front. A hover-opened notch stays open: `.dismissed` only closes a keyboard-opened one.
    private func copy(_ item: ClipboardItem) {
        module.copy(item)
        // The notch may close at once, so say what happened (L4).
        AccessibilityNotification.Announcement("Copied").post()
        query = ""
        dismissNotch()
    }

    /// Clear is gone once the history is empty, which would leave focus nowhere.
    private func clear() {
        module.clear()
        if focus == .clear { focus = .search }
    }

    private enum Focus: Hashable {
        case turnOn, search, addClipboard, clear
    }
}
