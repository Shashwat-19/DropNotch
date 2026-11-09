import Foundation

/// What the Calendar card lists (D44). Pure: the module passes the events, the time and the calendar, so tests
/// control all three.
struct UpcomingEvents: Equatable {
    enum Row: Equatable {
        /// Today's all-day events, on one line above the timed ones.
        case allDay([CalendarEvent])
        case event(CalendarEvent)
        /// After today's last event.
        case noMoreToday
        /// Nothing today at all.
        case noneToday
        /// Tomorrow's first event: the first timed one, else an all-day one.
        case tomorrow(CalendarEvent)
    }

    var rows: [Row]
    /// Today's events left out for lack of room: "+N".
    var hiddenCount: Int

    /// - Parameters:
    ///   - events: today's and tomorrow's events, in any order, hidden ones included.
    ///   - capacity: how many rows fit.
    init(events: [CalendarEvent], now: Date, calendar: Calendar, capacity: Int) {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        let endOfTomorrow = calendar.date(byAdding: .day, value: 2, to: startOfToday) ?? now
        // Start, then end, then id: events at the same time keep their places across reloads.
        let visible = events.filter { !$0.isHidden }.sorted { ($0.start, $0.end, $0.id) < ($1.start, $1.end, $1.id) }
        let today = visible.filter { $0.start < startOfTomorrow && $0.end > startOfToday }
        let allDay = today.filter(\.isAllDay)
        // An event in progress counts as upcoming until it ends.
        let timed = today.filter { !$0.isAllDay && $0.end > now }

        var all: [Row] = allDay.isEmpty ? [] : [.allDay(allDay)]
        all += timed.map(Row.event)
        if timed.isEmpty {
            all.append(today.isEmpty ? .noneToday : .noMoreToday)
            let tomorrow = visible.filter { $0.start >= startOfTomorrow && $0.start < endOfTomorrow }
            if let first = tomorrow.first(where: { !$0.isAllDay }) ?? tomorrow.first { all.append(.tomorrow(first)) }
        }
        let shown = max(capacity, 0)
        rows = Array(all.prefix(shown))
        hiddenCount = all.dropFirst(shown).reduce(0) { count, row in
            switch row {
            case .allDay(let events): count + events.count
            case .event: count + 1
            case .noMoreToday, .noneToday, .tomorrow: count
            }
        }
    }
}
