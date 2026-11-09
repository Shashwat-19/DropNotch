import SwiftUI

/// The Home tab's cards in one row, left to right in the order set in Settings (D42). Each card is a module's
/// `expandedView()` on a rounded card, sized by `HomeLayout`.
struct HomeView: View {
    /// The one module that reads the registry (D42); `NotchRootView` puts it in the environment.
    @Environment(ModuleRegistry.self) private var registry
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let cards = registry.homeCards
        if cards.isEmpty {
            NotchEmptyState("Turn on a Home card in Settings", systemImage: "square.grid.2x2")
        } else {
            GeometryReader { proxy in
                let widths = HomeLayout.widths(cards.compactMap(\.homeCard), total: proxy.size.width,
                                               spacing: NotchStyle.spacing)
                HStack(spacing: NotchStyle.spacing) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        self.card(card, width: widths[index], height: proxy.size.height)
                    }
                }
            }
        }
    }

    private func card(_ module: any NotchModule, width: CGFloat, height: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: NotchStyle.cardRadius, style: .continuous)
        return module.expandedView()
            .padding(NotchStyle.cardPadding)
            .frame(width: width, height: height)
            .background(shape.fill(.white.opacity(NotchStyle.cardFill)))
            // The fill alone is faint on black; Increase Contrast adds an edge so each card's bounds stay visible.
            .overlay { if contrast == .increased { shape.strokeBorder(.white.opacity(NotchStyle.cardEdge)) } }
            .clipShape(shape)
            // One group per card, named after its module, as the root view does for a tab (L4).
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(module.title))
    }
}
