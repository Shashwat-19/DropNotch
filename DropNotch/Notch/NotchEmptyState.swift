import SwiftUI

/// What a tab shows when it has nothing to show yet, or can't load: a symbol over a short line, centred in the
/// space below the top row, with an optional button under it (D37).
struct NotchEmptyState<Action: View>: View {
    let text: LocalizedStringKey
    let systemImage: String
    let action: Action
    @Environment(\.notchSize) private var size

    init(_ text: LocalizedStringKey, systemImage: String, @ViewBuilder action: () -> Action) {
        self.text = text
        self.systemImage = systemImage
        self.action = action()
    }

    var body: some View {
        VStack(spacing: NotchStyle.spacing) {
            VStack(spacing: NotchStyle.tightSpacing) {
                // Decoration: VoiceOver reads the text.
                Image(systemName: systemImage)
                    .font(.notch(.title2, size))
                    .accessibilityHidden(true)
                Text(text)
                    .font(.notch(.subheadline, size))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.secondary)
            // Its button steps up with the notch size too (D49).
            action
                .font(.notch(.body, size))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension NotchEmptyState where Action == EmptyView {
    init(_ text: LocalizedStringKey, systemImage: String) {
        self.init(text, systemImage: systemImage) { EmptyView() }
    }
}
