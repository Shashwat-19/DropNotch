import Foundation

/// Settings › General › "Show the notch on" (D9, D34). Saved in UserDefaults under `key`.
enum NotchDisplay: String, CaseIterable {
    /// The notched built-in screen, else the main display.
    case builtIn
    /// The display with the menu bar.
    case main

    static let key = "notch.display"

    static var saved: Self {
        UserDefaults.standard.string(forKey: key).flatMap(Self.init(rawValue:)) ?? .builtIn
    }
}
