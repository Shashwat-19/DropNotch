import CoreGraphics

/// Settings › Terminal (D48): stored in defaults, read through these so an out-of-range value falls back.
enum TerminalSettings {
    static let fontSizeKey = "terminal.fontSize"
    static let scrollbackKey = "terminal.scrollback"
    static let fontSizes = 10...14
    static let defaultFontSize = 11
    static let scrollbackChoices = [1_000, 5_000, 10_000]
    static let defaultScrollback = 1_000

    static func fontSize(_ stored: Int) -> CGFloat { CGFloat(fontSizes.contains(stored) ? stored : defaultFontSize) }
    static func scrollback(_ stored: Int) -> Int { scrollbackChoices.contains(stored) ? stored : defaultScrollback }
}
