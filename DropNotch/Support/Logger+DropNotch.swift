import os

/// One logger per module (CLAUDE.md). Never log user content.
extension Logger {
    private static let subsystem = "com.shashwat.DropNotch"

    static let notch = Logger(subsystem: subsystem, category: "Notch")
}
