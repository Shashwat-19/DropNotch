import XCTest
@testable import DropNotch

@MainActor
final class LockScreenPlayerTests: XCTestCase {
    private final class FakeLocks: LockStateSource {
        let stream: AsyncStream<Bool>
        private(set) var subscriptions = 0
        init(stream: AsyncStream<Bool>) { self.stream = stream }
        var changes: AsyncStream<Bool> {
            subscriptions += 1
            return stream
        }
    }

    private final class FakeSurface: LockScreenSurface {
        var placeable = true
        private(set) var isShown = false
        private(set) var shows = 0
        func show() -> Bool {
            shows += 1
            isShown = placeable
            return placeable
        }
        func hide() { isShown = false }
    }

    private final class FakePlayers: NowPlayingSource {
        let stream: AsyncStream<NowPlayingInfo?>
        init(stream: AsyncStream<NowPlayingInfo?>) { self.stream = stream }
        var updates: AsyncStream<NowPlayingInfo?> { stream }
        func send(_ command: PlaybackCommand, to player: MediaPlayer) async -> AppleEventOutcome { .ok }
        func refresh(_ player: MediaPlayer) {}
    }

    private var suites: [String] = []

    private func makeDefaults(on: Bool) -> UserDefaults {
        let name = "LockScreenPlayerTests.\(UUID())"
        suites.append(name)
        let defaults = UserDefaults(suiteName: name)!
        defaults.set(on, forKey: LockScreenPlayer.key)
        return defaults
    }

    override func tearDown() {
        suites.forEach { UserDefaults(suiteName: $0)?.removePersistentDomain(forName: $0) }
        suites = []
        super.tearDown()
    }

    private let track = NowPlayingInfo(player: .music, state: .playing, title: "Song", artist: "Band", trackID: "1")

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<1000 where !condition() { await Task.yield() }
    }

    /// A started Now Playing module, the feed for its tracks, and a player around it.
    private func setUp(on: Bool = true, available: Bool = true) async
        -> (LockScreenPlayer, FakeSurface, AsyncStream<Bool>.Continuation, AsyncStream<NowPlayingInfo?>.Continuation, FakeLocks) {
        let (tracks, trackFeed) = AsyncStream.makeStream(of: NowPlayingInfo?.self)
        let nowPlaying = NowPlayingModule(source: FakePlayers(stream: tracks))
        nowPlaying.start()
        let (lockStream, lockFeed) = AsyncStream.makeStream(of: Bool.self)
        let locks = FakeLocks(stream: lockStream)
        let surface = FakeSurface()
        let player = LockScreenPlayer(nowPlaying: nowPlaying, locks: locks, surface: surface, isAvailable: available,
                                      defaults: makeDefaults(on: on))
        return (player, surface, lockFeed, trackFeed, locks)
    }

    func testOffByDefaultAndUnavailableNeverListens() async {
        let name = "LockScreenPlayerTests.default"
        XCTAssertFalse(UserDefaults(suiteName: name)!.bool(forKey: LockScreenPlayer.key))
        let (off, _, _, _, offLocks) = await setUp(on: false)
        off.refresh()
        XCTAssertFalse(off.isRunning)
        XCTAssertEqual(offLocks.subscriptions, 0)
        let (unavailable, _, _, _, locks) = await setUp(on: true, available: false)
        unavailable.refresh()
        XCTAssertFalse(unavailable.isRunning, "a macOS without the symbols never shows it (D55)")
        XCTAssertEqual(locks.subscriptions, 0)
    }

    func testShowsOnlyWhileLockedWithATrackAndHidesOnUnlock() async {
        let (player, surface, lock, tracks, _) = await setUp()
        player.refresh()
        lock.yield(true)
        await waitUntil { player.isLocked }
        XCTAssertFalse(surface.isShown, "nothing loaded: no empty card on the lock screen")
        tracks.yield(track)
        await waitUntil { surface.isShown }
        XCTAssertTrue(surface.isShown, "a track loading while locked shows it")
        lock.yield(false)
        await waitUntil { !surface.isShown }
        XCTAssertFalse(surface.isShown)
        lock.yield(true)
        await waitUntil { surface.isShown }
        XCTAssertTrue(surface.isShown)
        tracks.yield(nil)
        await waitUntil { !surface.isShown }
        XCTAssertFalse(surface.isShown, "the player quitting while locked hides it")
    }

    func testTurningItOffHidesItAtOnce() async {
        let (player, surface, lock, tracks, _) = await setUp()
        player.refresh()
        tracks.yield(track)
        lock.yield(true)
        await waitUntil { surface.isShown }
        player.stop()
        XCTAssertFalse(surface.isShown)
        XCTAssertFalse(player.isLocked)
    }

    func testAPlacementFailureLeavesNothingShown() async {
        let (player, surface, lock, tracks, _) = await setUp()
        surface.placeable = false
        player.refresh()
        tracks.yield(track)
        lock.yield(true)
        await waitUntil { surface.shows > 0 }
        XCTAssertFalse(surface.isShown)
    }

    func testWindowSitsCentredAboveThePasswordField() {
        let frame = LockScreenPlayerWindow.frame(on: CGRect(x: 0, y: 0, width: 1470, height: 956))
        XCTAssertEqual(frame.size, LockScreenPlayerWindow.size)
        XCTAssertEqual(frame.midX, 735)
        XCTAssertEqual(frame.midY, (956 * LockScreenPlayerWindow.heightShare).rounded(), accuracy: 1)
        XCTAssertEqual(frame.minX, frame.minX.rounded())
    }

    func testTheRealSpaceIsAvailableOnThisMac() {
        // Documents the probe's result on the build machine; on a macOS without the symbols this fails loudly in CI.
        XCTAssertTrue(SkyLightLockScreenSpace().isAvailable)
        XCTAssertFalse(SkyLightLockScreenSpace().attach(windowNumber: 0), "no window, nothing attached")
    }
}
