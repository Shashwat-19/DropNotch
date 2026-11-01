import SwiftUI

/// Spacing, type and motion shared by every module's open content, so the tabs look and move alike (D37).
/// Spacing is on a 4 pt grid. Text is `.subheadline` (11 pt) or larger; the note's editor uses `.body` for typing.
/// Icons take the size of the font they sit in: `.body` for the top row and actions, `.title3` for Now Playing's
/// controls, `.title2` for an empty state's symbol.
enum NotchStyle {
    /// Between the module's content and the shape's sides.
    static let sidePadding: CGFloat = 24
    /// Below the module's content, above the shape's rounded bottom.
    static let bottomPadding: CGFloat = 12
    /// Between blocks: rows of controls, a field and its list.
    static let spacing: CGFloat = 8
    /// Within one block: a title and its subtitle, tiles in a row.
    static let tightSpacing: CGFloat = 4
    /// Open, close, the compact wings and tab switches all use this one spring (D37). No bounce: an overshoot past
    /// the open size would be cut flat by the panel's edges.
    static let spring = Animation.spring(duration: 0.25, bounce: 0)
}
