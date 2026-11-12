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
    /// Access states only: never clipboard content, types or counts of what was copied.
    static let clipboard = Logger(subsystem: subsystem, category: "Clipboard")
    /// Access states, counts and error codes only: never titles, times or calendar names.
    static let calendar = Logger(subsystem: subsystem, category: "Calendar")
    /// Failures only: never a reading.
    static let battery = Logger(subsystem: subsystem, category: "Battery")
    /// Session starts and ends, exit statuses and signals only: never typed text, output, titles, folders, the
    /// environment or the shell's path (D48).
    static let terminal = Logger(subsystem: subsystem, category: "Terminal")
    /// Status codes and hosts only: never the city, coordinates or a reading (D53).
    static let weather = Logger(subsystem: subsystem, category: "Weather")
    /// Error domains and codes only.
    static let settings = Logger(subsystem: subsystem, category: "Settings")
}
