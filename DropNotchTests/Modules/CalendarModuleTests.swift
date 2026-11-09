import XCTest
@testable import DropNotch

@MainActor
final class CalendarModuleTests: XCTestCase {
    /// Stands in for EventKit: no store, no prompt.
    private final class FakeSource: CalendarSource {
        var access: CalendarAccess
        /// What `requestAccess()` returns; it also becomes `access`, as after a real prompt.
        var grant: CalendarAccess = .allowed
        private(set) var requests = 0
        var events: [CalendarEvent] = []
        private(set) var fetches = 0
        /// When set, `events(from:to:)` waits until `release()`.
        var suspends = false
        private var pending: [CheckedContinuation<Void, Never>] = []
        let changes: AsyncStream<Void>
        let changesContinuation: AsyncStream<Void>.Continuation

        init(access: CalendarAccess) {
            self.access = access
            (changes, changesContinuation) = AsyncStream.makeStream(of: Void.self)
        }

        func requestAccess() async -> CalendarAccess {
            requests += 1
            access = grant
            return grant
        }

        func events(from start: Date, to end: Date) async -> [CalendarEvent] {
            fetches += 1
            if suspends { await withCheckedContinuation { pending.append($0) } }
            return events
        }

        var isSuspended: Bool { !pending.isEmpty }

        func release() {
            pending.forEach { $0.resume() }
            pending = []
        }
    }

    private static let sample = CalendarEvent(id: "1", title: "Stand-up", start: Date(timeIntervalSince1970: 0),
                                              end: Date(timeIntervalSince1970: 60), isAllDay: false, colour: nil,
                                              isHidden: false)

    private var suites: [String] = []

    /// A throwaway defaults domain, so tests never touch the real preferences.
    private func makeDefaults() -> UserDefaults {
        let name = "CalendarModuleTests.\(UUID())"
        suites.append(name)
        return UserDefaults(suiteName: name)!
    }

    override func tearDown() {
        suites.forEach { UserDefaults(suiteName: $0)?.removePersistentDomain(forName: $0) }
        suites = []
        super.tearDown()
    }

    private func makeModule(_ source: FakeSource, center: NotificationCenter = NotificationCenter())
        -> CalendarModule {
        CalendarModule(source: source, defaults: makeDefaults(), center: center)
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<1000 where !condition() { await Task.yield() }
    }

    private func settle() async {
        for _ in 0..<100 { await Task.yield() }
    }

    /// Posts until a reload starts: the observer may not have subscribed yet on the first post.
    private func post(_ name: Notification.Name, to center: NotificationCenter, source: FakeSource) async {
        let before = source.fetches
        for _ in 0..<1000 where source.fetches == before {
            center.post(name: name, object: nil)
            await Task.yield()
        }
    }

    // MARK: Identity

    func testIsAMediumHomeCardWithoutCompactContent() {
        let module = makeModule(FakeSource(access: .notDetermined))
        XCTAssertEqual(module.id, "calendar")
        XCTAssertEqual(module.homeCard, .medium)
        XCTAssertFalse(module.hasCompactContent)
    }

    // MARK: Access

    func testStartNeverPromptsAndLoadsNothingWhileUndecided() async {
        let source = FakeSource(access: .notDetermined)
        source.events = [Self.sample]
        let module = makeModule(source)
        module.start()
        await settle()
        XCTAssertEqual(module.access, .notDetermined)
        XCTAssertEqual(source.requests, 0)
        XCTAssertEqual(source.fetches, 0)
        XCTAssertEqual(module.events, [])
    }

    func testRequestAccessAsksOnceAndLoadsAfterAGrant() async {
        let source = FakeSource(access: .notDetermined)
        source.events = [Self.sample]
        let module = makeModule(source)
        module.start()
        await module.requestAccess()
        XCTAssertEqual(source.requests, 1)
        XCTAssertEqual(module.access, .allowed)
        await waitUntil { module.events == [Self.sample] }
        XCTAssertEqual(module.events, [Self.sample])
        await module.requestAccess()
        XCTAssertEqual(source.requests, 1, "decided: no second prompt")
    }

    func testRequestAccessDoesNothingWhenNotRunning() async {
        let source = FakeSource(access: .notDetermined)
        let module = makeModule(source)
        await module.requestAccess()
        module.start()
        module.stop()
        await module.requestAccess()
        XCTAssertEqual(source.requests, 0)
    }

    func testRequestAccessDoesNothingOnceDecided() async {
        for access in [CalendarAccess.denied, .restricted, .allowed] {
            let source = FakeSource(access: access)
            let module = makeModule(source)
            module.start()
            await module.requestAccess()
            XCTAssertEqual(source.requests, 0, "\(access)")
        }
    }

    func testADeniedPromptLoadsNothing() async {
        let source = FakeSource(access: .notDetermined)
        source.grant = .denied
        let module = makeModule(source)
        module.start()
        await module.requestAccess()
        await settle()
        XCTAssertEqual(module.access, .denied)
        XCTAssertEqual(source.fetches, 0)
    }

    // MARK: Loading and refresh

    func testStartWithAccessLoadsEvents() async {
        let source = FakeSource(access: .allowed)
        source.events = [Self.sample]
        let module = makeModule(source)
        module.start()
        await waitUntil { module.events == [Self.sample] }
        XCTAssertEqual(module.events, [Self.sample])
        XCTAssertEqual(module.access, .allowed)
    }

    func testADatabaseChangeReloads() async {
        let source = FakeSource(access: .allowed)
        let module = makeModule(source)
        module.start()
        await waitUntil { source.fetches == 1 }
        source.events = [Self.sample]
        source.changesContinuation.yield()
        await waitUntil { module.events == [Self.sample] }
        XCTAssertEqual(module.events, [Self.sample])
        XCTAssertEqual(source.fetches, 2)
    }

    func testDayAndTimeZoneChangesReload() async {
        let center = NotificationCenter()
        let source = FakeSource(access: .allowed)
        let module = makeModule(source, center: center)
        module.start()
        await waitUntil { source.fetches == 1 }

        source.events = [Self.sample]
        await post(.NSCalendarDayChanged, to: center, source: source)
        await waitUntil { module.events == [Self.sample] }
        XCTAssertEqual(module.events, [Self.sample])

        let before = source.fetches
        await post(.NSSystemTimeZoneDidChange, to: center, source: source)
        XCTAssertGreaterThan(source.fetches, before)
    }

    // MARK: didOpen

    func testDidOpenAfterRevokingClearsEventsAndStopsObserving() async {
        let center = NotificationCenter()
        let source = FakeSource(access: .allowed)
        source.events = [Self.sample]
        let ended = expectation(description: "changes stream ended")
        source.changesContinuation.onTermination = { _ in ended.fulfill() }
        let module = makeModule(source, center: center)
        module.start()
        await waitUntil { module.events == [Self.sample] }

        source.access = .denied
        module.didOpen()
        XCTAssertEqual(module.access, .denied)
        XCTAssertEqual(module.events, [])
        await fulfillment(of: [ended], timeout: 5)

        let fetches = source.fetches
        center.post(name: .NSCalendarDayChanged, object: nil)
        center.post(name: .NSSystemTimeZoneDidChange, object: nil)
        await settle()
        XCTAssertEqual(source.fetches, fetches)
        XCTAssertEqual(module.events, [])
    }

    func testDidOpenAfterAllowingInSystemSettingsLoads() async {
        let source = FakeSource(access: .denied)
        source.events = [Self.sample]
        let module = makeModule(source)
        module.start()
        await settle()
        XCTAssertEqual(source.fetches, 0)

        source.access = .allowed
        module.didOpen()
        XCTAssertEqual(module.access, .allowed)
        await waitUntil { module.events == [Self.sample] }
        XCTAssertEqual(module.events, [Self.sample])
        XCTAssertEqual(source.requests, 0)
    }

    func testDidOpenWhileStoppedReadsNothing() async {
        let source = FakeSource(access: .notDetermined)
        let module = makeModule(source)
        source.access = .allowed
        module.didOpen()
        await settle()
        XCTAssertEqual(module.access, .notDetermined)
        XCTAssertEqual(source.fetches, 0)
    }

    // MARK: stop

    func testStopClearsEventsAndALateFetchDoesNotRepopulate() async {
        let source = FakeSource(access: .allowed)
        source.events = [Self.sample]
        let module = makeModule(source)
        module.start()
        await waitUntil { module.events == [Self.sample] }

        source.suspends = true
        source.changesContinuation.yield()
        await waitUntil { source.isSuspended }
        XCTAssertTrue(source.isSuspended)
        module.stop()
        XCTAssertEqual(module.events, [])
        source.release()
        await settle()
        XCTAssertEqual(module.events, [], "titles are cleared by stop() and stay cleared (D44)")
    }

    func testAFetchStartedAtLaunchFinishingAfterStopDoesNotRepopulate() async {
        let source = FakeSource(access: .allowed)
        source.events = [Self.sample]
        source.suspends = true
        let module = makeModule(source)
        module.start()
        await waitUntil { source.isSuspended }
        module.stop()
        source.release()
        await settle()
        XCTAssertEqual(module.events, [])
    }

    // MARK: Titles setting

    func testShowsTitlesDefaultsToOnAndPersists() {
        let defaults = makeDefaults()
        let source = FakeSource(access: .notDetermined)
        let first = CalendarModule(source: source, defaults: defaults, center: NotificationCenter())
        XCTAssertTrue(first.showsTitles)
        XCTAssertNil(defaults.object(forKey: "calendar.showsTitles"))
        first.showsTitles = false
        XCTAssertEqual(defaults.object(forKey: "calendar.showsTitles") as? Bool, false)
        let second = CalendarModule(source: source, defaults: defaults, center: NotificationCenter())
        XCTAssertFalse(second.showsTitles)
    }
}
