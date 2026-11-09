import Foundation

/// Where the Calendar card gets events (D44). `@MainActor`: its only consumer is the module.
@MainActor
protocol CalendarSource {
    /// Read without prompting.
    var access: CalendarAccess { get }
    /// Shows the system prompt if access is undecided, and returns the access afterwards.
    func requestAccess() async -> CalendarAccess
    /// Events overlapping `start..<end` in every calendar; empty without access.
    func events(from start: Date, to end: Date) async -> [CalendarEvent]
    /// Fires when the calendar database changes: an edit in any app, or a sync. Each access subscribes.
    var changes: AsyncStream<Void> { get }
}
