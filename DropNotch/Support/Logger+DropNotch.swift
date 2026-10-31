import os

/// One logger per module (CLAUDE.md). Never log user content.
extension Logger {
    private static let subsystem = "com.shashwat.DropNotch"

    static let notch = Logger(subsystem: subsystem, category: "Notch")
    /// Bundle IDs, states and OSStatus codes only: never titles, artists or Apple Event replies.
    static let nowPlaying = Logger(subsystem: subsystem, category: "NowPlaying")
    /// Error domains and codes only: never the note or its path.
    static let notes = Logger(subsystem: subsystem, category: "Notes")
    /// Error domains and codes only: never file names or paths.
    static let tray = Logger(subsystem: subsystem, category: "FileTray")
}
