import os

/// One logger per module (CLAUDE.md). Never log user content.
extension Logger {
    private static let subsystem = "com.shashwat.DropNotch"

    static let notch = Logger(subsystem: subsystem, category: "Notch")
    /// Bundle IDs, states and OSStatus codes only: never titles, artists or Apple Event replies.
    static let nowPlaying = Logger(subsystem: subsystem, category: "NowPlaying")
}
