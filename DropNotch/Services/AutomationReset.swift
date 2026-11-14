import Foundation
import os

/// Clears DropNotch's own Automation record, so the next permission check asks again (D59). A protocol so the source is
/// tested without touching the real record.
protocol AutomationResetting: Sendable {
    /// Whether the record was cleared.
    func resetAutomation() async -> Bool
}

/// The real one: `tccutil reset AppleEvents <our bundle ID>`, which needs no admin rights and touches only DropNotch's
/// own grants, for every app it controls (D59).
struct TCCUtilAutomationReset: AutomationResetting {
    func resetAutomation() async -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            process.arguments = ["reset", "AppleEvents", bundleID]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            // Called on a background thread when tccutil exits; it never runs if `run()` throws.
            process.terminationHandler = { finished in
                let status = finished.terminationStatus
                Logger.nowPlaying.info("Automation reset: tccutil exited \(status)")
                continuation.resume(returning: status == 0)
            }
            do {
                try process.run()
            } catch {
                Logger.nowPlaying.error("Automation reset: tccutil didn't start: \(error.localizedDescription, privacy: .public)")
                continuation.resume(returning: false)
            }
        }
    }
}
