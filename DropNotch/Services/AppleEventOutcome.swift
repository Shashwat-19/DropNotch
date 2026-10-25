import CoreServices

/// What happened to an Apple Event or a permission check (D23). Every status maps to a case, so none can crash.
enum AppleEventOutcome: Equatable {
    case ok
    /// The user said no, now or earlier, in the Automation prompt or System Settings.
    case denied
    /// Only from a check that may not prompt: the user hasn't been asked yet.
    case needsConsent
    case notRunning
    case timedOut
    case failed(OSStatus)

    init(status: OSStatus) {
        self = switch Int(status) {
        case Int(noErr): .ok
        case Int(errAEEventNotPermitted): .denied
        case Int(errAEEventWouldRequireUserConsent): .needsConsent
        case Int(procNotFound), Int(connectionInvalid): .notRunning
        case Int(errAETimeout): .timedOut
        default: .failed(status)
        }
    }
}
