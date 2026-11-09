import CoreGraphics
import Foundation

/// One event as the Calendar card needs it (D44). Built inside the service, so EventKit objects never leave it.
/// The title stays in memory: it is never logged or saved.
struct CalendarEvent: Equatable, Sendable {
    /// Unique per occurrence: a repeating event's occurrences share EventKit's identifier.
    var id: String
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    /// The calendar's colour; nil uses the accent colour.
    var colour: CGColor?
    /// Cancelled, or declined by the user: never shown (D44).
    var isHidden: Bool
}
