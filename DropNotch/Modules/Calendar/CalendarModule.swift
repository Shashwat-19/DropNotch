import SwiftUI
import os

/// Today's next events as the medium Home card (D44). Reads only, asks for access only when the user asks.
@MainActor
@Observable
final class CalendarModule: NotchModule {
    let id = "calendar"
    let title: LocalizedStringResource = "Calendar"
    let systemImage = "calendar"
    let hasCompactContent = false
    let homeCard: HomeCardSize? = .medium
    private(set) var access: CalendarAccess = .notDetermined
    /// Today's and tomorrow's events. Memory only, never logged or saved; `stop()` clears them (D44).
    private(set) var events: [CalendarEvent] = []
    /// "Show event titles" in Settings › Privacy (D44). Off shows times only.
    var showsTitles: Bool { didSet { defaults.set(showsTitles, forKey: Self.showsTitlesKey) } }

    private let source: any CalendarSource
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let center: NotificationCenter
    @ObservationIgnored private var isRunning = false
    /// The change, day and time-zone observers; running only while access is allowed.
    @ObservationIgnored private var observers: [Task<Void, Never>] = []

    /// `center` is internal for tests; the system posts the day and time-zone changes to the default one.
    init(source: any CalendarSource, defaults: UserDefaults = .standard, center: NotificationCenter = .default) {
        self.source = source
        self.defaults = defaults
        self.center = center
        showsTitles = defaults.object(forKey: Self.showsTitlesKey) as? Bool ?? true
    }

    func compactView(slot: CompactSlot) -> AnyView { AnyView(EmptyView()) }

    func expandedView() -> AnyView { AnyView(CalendarCardView(module: self)) }

    func settingsView() -> AnyView { AnyView(EmptyView()) }

    /// Only reads the access status: the prompt never appears at launch (D44).
    func start() {
        guard !isRunning else { return }
        isRunning = true
        updateAccess(source.access)
    }

    func stop() {
        isRunning = false
        observers.forEach { $0.cancel() }
        observers = []
        events = []
    }

    /// The card appeared, once per open (D19): re-read the status, so a change made in System Settings shows
    /// without a relaunch.
    func didOpen() {
        guard isRunning else { return }
        updateAccess(source.access)
    }

    /// The card's Allow button, or the card turned on in Settings (D44). Prompts only while access is undecided.
    func requestAccess() async {
        guard isRunning, access == .notDetermined else { return }
        let result = await source.requestAccess()
        guard isRunning else { return }
        updateAccess(result)
    }

    /// Fetches today's and tomorrow's events. Internal so tests can wait for it.
    func reload() async {
        let calendar = Calendar.autoupdatingCurrent
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 2, to: start) else { return }
        let fetched = await source.events(from: start, to: end)
        // `stop()` or a revoked grant during the fetch.
        guard isRunning, access == .allowed else { return }
        events = fetched
        Logger.calendar.debug("Loaded \(fetched.count) events")
    }

    private func updateAccess(_ new: CalendarAccess) {
        if access != new { Logger.calendar.info("Access: \(String(describing: new), privacy: .public)") }
        access = new
        guard new == .allowed else {
            observers.forEach { $0.cancel() }
            observers = []
            events = []
            return
        }
        guard observers.isEmpty else { return }
        // No timer (D44): the calendar database, the date and the time zone each say when they change.
        observers = [
            Task { [weak self, source] in for await _ in source.changes { await self?.reload() } },
            Task { [weak self, center] in
                for await _ in center.notifications(named: .NSCalendarDayChanged) { await self?.reload() }
            },
            Task { [weak self, center] in
                for await _ in center.notifications(named: .NSSystemTimeZoneDidChange) { await self?.reload() }
            },
            Task { [weak self] in await self?.reload() },
        ]
    }

    static let showsTitlesKey = "calendar.showsTitles"
}
