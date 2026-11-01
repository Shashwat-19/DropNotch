import SwiftUI

/// Dock-style selection for tabs, tray tiles and clipboard rows (D39): the selected item is white with a small dot,
/// and while its group has a selection the other items dim to grey. The dot carries the state on its own, so it never
/// rests on brightness or colour (L6); Increase Contrast brightens the grey.
struct NotchSelection: ViewModifier {
    let isSelected: Bool
    /// Whether the group has a selection, so the items that aren't selected dim.
    let groupHasSelection: Bool
    /// Where the dot sits (below a tab or tile, beside a row) and how far it is moved from there.
    let dotAlignment: Alignment
    var dotOffset = CGSize.zero
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .foregroundStyle(.white.opacity(Self.opacity(isSelected: isSelected, groupHasSelection: groupHasSelection,
                                                         increasedContrast: contrast == .increased)))
            .overlay(alignment: dotAlignment) {
                if isSelected {
                    Circle().fill(.white).frame(width: 4, height: 4).offset(dotOffset).accessibilityHidden(true)
                }
            }
    }

    /// 50 % white on black is 5.3:1, enough for text as well as icons; 75 % under Increase Contrast.
    static func opacity(isSelected: Bool, groupHasSelection: Bool, increasedContrast: Bool) -> Double {
        isSelected || !groupHasSelection ? 1 : increasedContrast ? 0.75 : 0.5
    }
}

extension View {
    func notchSelection(_ isSelected: Bool, groupHasSelection: Bool, dot alignment: Alignment,
                        offset: CGSize = .zero) -> some View {
        modifier(NotchSelection(isSelected: isSelected, groupHasSelection: groupHasSelection,
                                dotAlignment: alignment, dotOffset: offset))
    }
}
