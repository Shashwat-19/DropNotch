import EventKit

/// What the Calendar card may do (D44). macOS 14 has no read-only level, so reading needs full access.
enum CalendarAccess: Equatable {
    case notDetermined, allowed, denied, restricted

    init(_ status: EKAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        // `.authorized`, deprecated in macOS 14, has the same raw value as `.fullAccess`.
        case .fullAccess: self = .allowed
        case .restricted: self = .restricted
        // Write-only access can't read events, so for this card it is the same as denied.
        case .denied, .writeOnly: self = .denied
        @unknown default: self = .denied
        }
    }
}
