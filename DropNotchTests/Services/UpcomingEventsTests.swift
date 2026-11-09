import XCTest
@testable import DropNotch

final class UpcomingEventsTests: XCTestCase {
    /// A fixed calendar and zone, so the tests never depend on the Mac's settings or the real clock.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// 2026-11-09, a Monday, in London (GMT).
    private func today(_ hour: Int, _ minute: Int = 0) -> Date { date(2026, 11, 9, hour, minute) }
    private func tomorrow(_ hour: Int, _ minute: Int = 0) -> Date { date(2026, 11, 10, hour, minute) }

    private func event(_ id: String, _ start: Date, _ end: Date, allDay: Bool = false,
                       hidden: Bool = false) -> CalendarEvent {
        CalendarEvent(id: id, title: "Title \(id)", start: start, end: end, isAllDay: allDay, colour: nil,
                      isHidden: hidden)
    }

    /// An all-day event from the start of `day` for `days` days.
    private func allDay(_ id: String, _ day: Date, days: Int = 1, hidden: Bool = false) -> CalendarEvent {
        let start = calendar.startOfDay(for: day)
        return event(id, start, calendar.date(byAdding: .day, value: days, to: start)!, allDay: true, hidden: hidden)
    }

    private func upcoming(_ events: [CalendarEvent], now: Date, capacity: Int = 10) -> UpcomingEvents {
        UpcomingEvents(events: events, now: now, calendar: calendar, capacity: capacity)
    }

    /// Rows as short strings, so a failure shows the whole list at a glance.
    private func describe(_ upcoming: UpcomingEvents) -> [String] {
        upcoming.rows.map { row in
            switch row {
            case .allDay(let events): "allDay(\(events.map(\.id).sorted().joined(separator: ",")))"
            case .event(let event): event.id
            case .noMoreToday: "noMoreToday"
            case .noneToday: "noneToday"
            case .tomorrow(let event): "tomorrow(\(event.id))"
            }
        }
    }

    // MARK: Today

    func testTimedEventsAreSortedByStartAndAnEventInProgressCountsButAnEndedOneDoesNot() {
        let result = upcoming([
            event("15", today(15), today(16)),
            event("ended", today(9), today(10)),
            event("13", today(13), today(14)),
            event("inProgress", today(11, 30), today(12, 30)),
            event("endsNow", today(11), today(12)),
        ], now: today(12))
        XCTAssertEqual(describe(result), ["inProgress", "13", "15"])
        XCTAssertEqual(result.hiddenCount, 0)
    }

    func testAllDayEventsShareOneRowAboveTheTimedOnesIncludingAMultiDayOneSpanningToday() {
        let result = upcoming([
            event("14", today(14), today(15)),
            allDay("birthday", today(0)),
            allDay("holiday", today(0)),
            allDay("conference", date(2026, 11, 8), days: 4),
            allDay("yesterday", date(2026, 11, 8)),
            allDay("tomorrowAllDay", tomorrow(0)),
        ], now: today(12))
        XCTAssertEqual(describe(result), ["allDay(birthday,conference,holiday)", "14"])
        guard case .allDay(let events) = result.rows.first else { return XCTFail("no all-day row") }
        XCTAssertEqual(events.first?.id, "conference", "sorted by start: the multi-day one began yesterday")
    }

    func testATimedEventThatStartedYesterdayAndEndsLaterTodayIsIncluded() {
        let result = upcoming([event("overnight", date(2026, 11, 8, 22), today(14))], now: today(12))
        XCTAssertEqual(describe(result), ["overnight"])
    }

    func testHiddenEventsNeverAppearTodayOrTomorrow() {
        let result = upcoming([
            event("cancelled", today(14), today(15), hidden: true),
            allDay("declinedAllDay", today(0), hidden: true),
            event("declinedTomorrow", tomorrow(8), tomorrow(9), hidden: true),
            event("tomorrow10", tomorrow(10), tomorrow(11)),
        ], now: today(12))
        // Only hidden events today counts as nothing today.
        XCTAssertEqual(describe(result), ["noneToday", "tomorrow(tomorrow10)"])
    }

    // MARK: After today's last event

    func testNoMoreTodayThenTomorrowsEarliestTimedEvent() {
        let result = upcoming([
            event("morning", today(9), today(10)),
            allDay("tomorrowAllDay", tomorrow(0)),
            event("tomorrow11", tomorrow(11), tomorrow(12)),
            event("tomorrow9", tomorrow(9), tomorrow(10)),
        ], now: today(18))
        XCTAssertEqual(describe(result), ["noMoreToday", "tomorrow(tomorrow9)"])
        XCTAssertEqual(result.hiddenCount, 0)
    }

    func testNothingTodayThenTomorrow() {
        let result = upcoming([event("tomorrow9", tomorrow(9), tomorrow(10))], now: today(8))
        XCTAssertEqual(describe(result), ["noneToday", "tomorrow(tomorrow9)"])
    }

    func testTomorrowFallsBackToAnAllDayEvent() {
        let result = upcoming([allDay("tomorrowAllDay", tomorrow(0))], now: today(8))
        XCTAssertEqual(describe(result), ["noneToday", "tomorrow(tomorrowAllDay)"])
    }

    func testNoTomorrowRowWithoutEventsTomorrowAndTheDayAfterIsIgnored() {
        XCTAssertEqual(describe(upcoming([], now: today(8))), ["noneToday"])
        let result = upcoming([
            event("morning", today(9), today(10)),
            event("dayAfter", date(2026, 11, 11, 8), date(2026, 11, 11, 9)),
            allDay("dayAfterAllDay", date(2026, 11, 11)),
        ], now: today(18))
        XCTAssertEqual(describe(result), ["noMoreToday"])
    }

    func testOnlyAllDayEventsTodayShowTheRowThenNoMoreToday() {
        let result = upcoming([allDay("holiday", today(0)), event("tomorrow9", tomorrow(9), tomorrow(10))],
                              now: today(12))
        XCTAssertEqual(describe(result), ["allDay(holiday)", "noMoreToday", "tomorrow(tomorrow9)"])
    }

    // MARK: Capacity

    private var busyDay: [CalendarEvent] {
        [allDay("a1", today(0)), allDay("a2", today(0))] + (13...17).map { event("\($0)", today($0), today($0, 30)) }
    }

    func testRowsAreTruncatedAndHiddenCountCountsHiddenEvents() {
        let three = upcoming(busyDay, now: today(12), capacity: 3)
        XCTAssertEqual(describe(three), ["allDay(a1,a2)", "13", "14"])
        XCTAssertEqual(three.hiddenCount, 3)

        let one = upcoming(busyDay, now: today(12), capacity: 1)
        XCTAssertEqual(describe(one), ["allDay(a1,a2)"])
        XCTAssertEqual(one.hiddenCount, 5)

        let all = upcoming(busyDay, now: today(12), capacity: 7)
        XCTAssertEqual(all.rows.count, 6)
        XCTAssertEqual(all.hiddenCount, 0)
    }

    func testAHiddenAllDayRowCountsEachOfItsEvents() {
        for capacity in [0, -1, -100] {
            let result = upcoming(busyDay, now: today(12), capacity: capacity)
            XCTAssertEqual(result.rows, [], "capacity \(capacity)")
            XCTAssertEqual(result.hiddenCount, 7, "capacity \(capacity): 2 all-day + 5 timed")
        }
    }

    func testStatusAndTomorrowRowsCountNothingWhenHidden() {
        let events = [allDay("holiday", today(0)), event("tomorrow9", tomorrow(9), tomorrow(10))]
        let one = upcoming(events, now: today(12), capacity: 1)
        XCTAssertEqual(describe(one), ["allDay(holiday)"])
        XCTAssertEqual(one.hiddenCount, 0)

        let none = upcoming([event("tomorrow9", tomorrow(9), tomorrow(10))], now: today(12), capacity: 0)
        XCTAssertEqual(none.rows, [])
        XCTAssertEqual(none.hiddenCount, 0)
    }

    // MARK: Daylight saving

    /// London's clocks go forward at 01:00 on 2026-03-29: a 23-hour day. Adding 24 hours would put tomorrow's
    /// 00:30 into today.
    func testStartOfTomorrowOnAShortDay() {
        let result = upcoming([
            event("late", date(2026, 3, 29, 23), date(2026, 3, 29, 23, 30)),
            event("justAfterMidnight", date(2026, 3, 30, 0, 30), date(2026, 3, 30, 1)),
        ], now: date(2026, 3, 29, 12))
        XCTAssertEqual(describe(result), ["late"])
        let evening = upcoming([
            event("justAfterMidnight", date(2026, 3, 30, 0, 30), date(2026, 3, 30, 1)),
            event("lateTomorrow", date(2026, 3, 30, 23, 30), date(2026, 3, 30, 23, 45)),
        ], now: date(2026, 3, 29, 23, 45))
        XCTAssertEqual(describe(evening), ["noneToday", "tomorrow(justAfterMidnight)"])
    }

    /// London's clocks go back at 02:00 on 2026-10-25: a 25-hour day. Adding 24 hours would push today's 23:30
    /// into tomorrow.
    func testStartOfTomorrowOnALongDay() {
        let result = upcoming([event("late", date(2026, 10, 25, 23, 30), date(2026, 10, 25, 23, 45))],
                              now: date(2026, 10, 25, 12))
        XCTAssertEqual(describe(result), ["late"])
    }
}
