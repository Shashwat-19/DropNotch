import SwiftUI

/// Behind a selected tab, tile or row (D37). The edge keeps the selection above 3:1 on black, which the 20 % fill
/// alone isn't, and grows stronger under Increase Contrast (L6).
struct NotchSelection<S: InsettableShape>: View {
    let shape: S
    let isSelected: Bool
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        if isSelected {
            shape.fill(NotchStyle.selectionFill)
                .overlay(shape.strokeBorder(.white.opacity(contrast == .increased ? 0.9 : 0.6), lineWidth: 1))
        }
    }
}
