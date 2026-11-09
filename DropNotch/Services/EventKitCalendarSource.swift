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
        /// Lazy, so it is built on this actor the first time it's needed, not on the main thread at launch, and never
        /// for someone who doesn't use the card (code-reviewer W1).
        private lazy var store = EKEventStore()
        /// Whether the last fetch had access; a change to allowed resets the store first.
        private var hadAccess = false

        func requestFullAccess() async throws {
            _ = try await store.requestFullAccessToEvents()
        }

        /// shortcut: one synchronous fetch, blocking this actor (not the main thread) for its length; fine for two days of
        /// events [I: not measured]. Upgrade to `enumerateEvents` in chunks if performance-optimizer measures it slow.
        func events(from start: Date, to end: Date) -> [CalendarEvent] {
            // A store made before access was granted, by the prompt or in System Settings, may not see the calendars
            // until it is reset [I: device check] (code-reviewer W2).
            let hasAccess = EKEventStore.authorizationStatus(for: .event) == .fullAccess
            if hasAccess, !hadAccess { store.reset() }
            hadAccess = hasAccess
            let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
            return store.events(matching: predicate).map(CalendarEvent.init)
        }
    }
}

private extension CalendarEvent {
    init(_ event: EKEvent) {
        let declined = event.attendees?.contains { $0.isCurrentUser && $0.participantStatus == .declined } == true
        self.init(id: "\(event.calendarItemIdentifier)@\(event.startDate.timeIntervalSinceReferenceDate)",
                  title: event.title ?? "", start: event.startDate, end: event.endDate, isAllDay: event.isAllDay,
                  colour: event.calendar?.cgColor, isHidden: event.status == .canceled || declined)
    }
}
