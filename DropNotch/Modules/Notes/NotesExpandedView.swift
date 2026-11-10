import SwiftUI

/// The note in the open notch: a plain-text editor with a placeholder while it is empty (D31).
struct NotesExpandedView: View {
    @Bindable var module: NotesModule
    @FocusState private var isFocused: Bool
    @Environment(\.notchHasKeyboardFocus) private var hasKeyboardFocus
    @Environment(\.requestNotchKeyboardFocus) private var requestKeyboardFocus
    @Environment(\.notchSize) private var size

    var body: some View {
        VStack(spacing: NotchStyle.tightSpacing) {
            if module.loadFailed {
                NotchEmptyState("Couldn't open the note file", systemImage: "exclamationmark.triangle")
            } else {
                TextEditor(text: $module.text)
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                    .overlay(alignment: .topLeading) {
                        if module.text.isEmpty {
                            Text("Type a note")
                                .foregroundStyle(.secondary)
                                // Lines up with the cursor: the text view pads each line by 5 pt.
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                    // Hover never makes the panel key (D30), so without this a click would put the cursor here
                    // while the keys still went to the app in front. The click takes keyboard focus instead.
                    .overlay {
                        if !hasKeyboardFocus {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { requestKeyboardFocus() }
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityLabel(Text(module.title))
                    // Set explicitly, as in Now Playing: the panel turns key before SwiftUI inserts this view (D30).
                    .onChange(of: hasKeyboardFocus, initial: true) { if hasKeyboardFocus { isFocused = true } }
                if module.saveFailed {
                    Text("Couldn't save the note")
                        .font(.notch(.subheadline, size))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .font(.notch(.body, size))
    }
}
