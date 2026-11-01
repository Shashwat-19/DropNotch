import SwiftUI

/// What a tab shows when it has nothing to show yet, or can't load: a symbol over a short line, centred in the
/// space below the top row, with an optional button under it (D37).
struct NotchEmptyState<Action: View>: View {
    let text: LocalizedStringKey
    let systemImage: String
    @ViewBuilder let action: Action

    var body: some View {
        VStack(spacing: NotchStyle.spacing) {
            VStack(spacing: NotchStyle.tightSpacing) {
                // Decoration: VoiceOver reads the text.
                Image(systemName: systemImage)
                    .font(.title2)
                    .accessibilityHidden(true)
                Text(text)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.secondary)
            action
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension NotchEmptyState where Action == EmptyView {
    init(_ text: LocalizedStringKey, systemImage: String) {
        self.init(text: text, systemImage: systemImage) { EmptyView() }
    }
}
