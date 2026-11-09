import EventKit
import os

/// `CalendarSource` from EventKit (D44): reads only, never writes.
@MainActor
final class EventKitCalendarSource: CalendarSource {
    private let reader = Reader()

    var access: CalendarAccess { CalendarAccess(EKEventStore.authorizationStatus(for: .event)) }

    func requestAccess() async -> CalendarAccess {
        guard access == .notDetermined else { return access }
        do {
            try await reader.requestFullAccess()
        } catch {
            let error = error as NSError
            Logger.calendar.error("Access request failed: \(error.domain, privacy: .public) \(error.code)")
        }
        return access
    }

    func events(from start: Date, to end: Date) async -> [CalendarEvent] {
        guard access == .allowed else { return [] }
        return await reader.events(from: start, to: end)
    }

    var changes: AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            // Any store's changes: the reader's is the only store in DropNotch, and it can't leave its actor.
            let task = Task {
                for await _ in NotificationCenter.default.notifications(named: .EKEventStoreChanged) { continuation.yield() }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Owns the store, so it is only ever used from one place at a time and off the main thread [I: EventKit doesn't
    /// document the store as thread-safe]. One store for the app's lifetime, as Apple advises; creating it doesn't prompt.
    private actor Reader {
        private let store = EKEventStore()

        func requestFullAccess() async throws {
            let granted = try await store.requestFullAccessToEvents()
            // A store made before the grant may not see the calendars until it is reset [I].
            if granted { store.reset() }
        }

        /// shortcut: one synchronous fetch, blocking this actor (not the main thread) for its length; fine for two days of
        /// events [I: not measured]. Upgrade to `enumerateEvents` in chunks if performance-optimizer measures it slow.
        func events(from start: Date, to end: Date) -> [CalendarEvent] {
            let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
            return store.events(matching: predicate).map(CalendarEvent.init)
        }
    }
}

private extension CalendarEvent {
    init(_ event: EKEvent) {
        let declined = event.attendees?.first(where: \.isCurrentUser)?.participantStatus == .declined
        self.init(id: "\(event.calendarItemIdentifier)@\(event.startDate.timeIntervalSinceReferenceDate)",
                  title: event.title ?? "", start: event.startDate, end: event.endDate, isAllDay: event.isAllDay,
                  colour: event.calendar?.cgColor, isHidden: event.status == .canceled || declined)
    }
}
