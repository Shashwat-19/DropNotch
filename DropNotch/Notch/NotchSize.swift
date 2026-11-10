import SwiftUI

/// Settings › General › Notch size (D49). Each is one fixed open size for every tab (D16, D29); it changes only from
/// Settings. Large is 40 pt taller and 80 pt wider than Standard, with text and controls one step up.
enum NotchSize: String {
    case standard, large

    static let key = "notch.size"

    /// The saved choice; Standard for new installs and for anything unrecognised.
    static func saved(_ defaults: UserDefaults = .standard) -> NotchSize {
        defaults.string(forKey: key).flatMap(NotchSize.init(rawValue:)) ?? .standard
    }

    /// The open shape's height: Standard is `NotchGeometry.openSize` (190 pt, D46), Large 40 pt more.
    var openHeight: CGFloat { NotchGeometry.openSize.height + (self == .large ? 40 : 0) }
    /// Added to the width the top row needs, whatever tabs are on: 676 pt with six top-row items on the Air, 616 with
    /// five or fewer.
    var addedWidth: CGFloat { self == .large ? 80 : 0 }

    /// A fixed size in the notch (a row, a control) for this size: Large is one text step up, body's 13 → 15, so the
    /// ratio 15/13, rounded to whole points: 14 → 16, 24 → 28, 28 → 32 (docs/mockups/notch-size-v0.2.html).
    func scaled(_ standard: CGFloat) -> CGFloat {
        self == .large ? (standard * 15 / 13).rounded() : standard
    }
}

extension EnvironmentValues {
    /// The notch size the open content is drawn at (D49).
    @Entry var notchSize = NotchSize.standard
}

/// The notch's text styles (NotchStyle, D37) at a notch size: Standard keeps the system text styles, Large is one step
/// up (11 → 13, 13 → 15, 15 → 17, 17 → 20).
enum NotchTextStyle {
    case subheadline, body, title3, title2
}

extension Font {
    static func notch(_ style: NotchTextStyle, _ size: NotchSize) -> Font {
        switch (style, size) {
        case (.subheadline, .standard): .subheadline
        case (.body, .standard): .body
        case (.title3, .standard): .title3
        case (.title2, .standard): .title2
        case (.subheadline, .large): .system(size: 13)
        case (.body, .large): .system(size: 15)
        case (.title3, .large): .system(size: 17)
        case (.title2, .large): .system(size: 20)
        }
    }
}
