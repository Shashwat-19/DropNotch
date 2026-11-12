import SwiftUI

/// Weather and air quality for a city chosen in Settings, as a narrow Home card (D53). Off by default. Nothing goes
/// over the network while it's off, before a city is chosen, or while the notch is closed: a reading is fetched only
/// when the card appears and the last one is more than 30 minutes old.
@MainActor
@Observable
final class WeatherModule: NotchModule {
    let id = "weather"
    let title: LocalizedStringResource = "Weather"
    let systemImage = "cloud.sun"
    let hasCompactContent = false
    let homeCard: HomeCardSize? = .narrow
    /// It sends the city's coordinates to Open-Meteo, so the user turns it on (D53).
    let isEnabledByDefault = false

    /// How old a reading may be before the card's next appearance fetches a new one (D53).
    static let refreshAge: TimeInterval = 30 * 60
    /// After a failure, the card waits this long before trying again, however often it's opened.
    static let retryAge: TimeInterval = 60

    private(set) var place: WeatherPlace?
    /// Memory only; `stop()` and a new city clear it.
    private(set) var reading: WeatherReading?
    private(set) var failed = false
    private(set) var isLoading = false

    private let source: any WeatherSource
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var isRunning = false
    @ObservationIgnored private var lastAttempt = Date.distantPast
    /// Moves on with each fetch and each `stop()`, so only the newest fetch lands (as CalendarModule does).
    @ObservationIgnored private var latestFetch = 0

    /// `defaults` and `now` are for tests.
    init(source: any WeatherSource, defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.source = source
        self.defaults = defaults
        self.now = now
        place = WeatherPlace.saved(defaults)
    }

    func compactView(slot: CompactSlot) -> AnyView { AnyView(EmptyView()) }

    func expandedView() -> AnyView { AnyView(WeatherCardView(module: self)) }

    func settingsView() -> AnyView { AnyView(EmptyView()) }

    /// No network: only reads the saved city.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        place = WeatherPlace.saved(defaults)
    }

    func stop() {
        isRunning = false
        latestFetch += 1
        reading = nil
        failed = false
        isLoading = false
        lastAttempt = .distantPast
    }

    /// Whether the card's next appearance should fetch.
    var needsRefresh: Bool {
        guard isRunning, place != nil, !isLoading else { return false }
        if let reading { return now().timeIntervalSince(reading.fetchedAt) > Self.refreshAge }
        return now().timeIntervalSince(lastAttempt) > Self.retryAge
    }

    /// The card appeared (once per open, D19): fetch if the reading is stale.
    func didOpen() {
        guard needsRefresh else { return }
        Task { await refresh() }
    }

    /// Fetches a reading for the chosen city. Internal so tests can wait for it.
    func refresh() async {
        guard isRunning, let place else { return }
        latestFetch += 1
        let fetch = latestFetch
        isLoading = true
        lastAttempt = now()
        do {
            var new = try await source.reading(at: place)
            guard fetch == latestFetch else { return }
            new.fetchedAt = now()
            reading = new
            failed = false
        } catch {
            guard fetch == latestFetch else { return }
            failed = true
        }
        isLoading = false
    }

    /// Settings › Weather: places matching what the user typed. Works with the card off, so a city can be chosen first.
    func search(_ name: String) async throws -> [WeatherPlace] {
        try await source.places(matching: name)
    }

    /// Settings › Weather: saves the city (or removes it) and, if the card is on, fetches for it at once.
    func choose(_ new: WeatherPlace?) {
        WeatherPlace.save(new, defaults)
        place = new
        latestFetch += 1
        reading = nil
        failed = false
        isLoading = false
        lastAttempt = .distantPast
        if isRunning, new != nil { Task { await refresh() } }
    }
}
