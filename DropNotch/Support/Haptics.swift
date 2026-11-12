import AppKit

/// A light tap on a Force Touch trackpad when the notch shows an alert (D52). macOS plays it only while a finger rests
/// on the trackpad; otherwise nothing happens.
enum Haptics {
    /// Settings › General › Haptic feedback. On when nothing is saved.
    static let key = "haptics.enabled"

    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: key) as? Bool ?? true
    }

    @MainActor
    static func tap(_ defaults: UserDefaults = .standard) {
        guard isEnabled(defaults) else { return }
        // `.alignment` is the subtlest of the three public patterns; `.now` plays it at once.
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}
