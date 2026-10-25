import XCTest
@testable import DropNotch

@MainActor
final class ScriptablePlayersSourceTests: XCTestCase {
    /// Records every call. An actor because the protocol's methods run off the main actor.
    private actor FakeSender: AppleEventSending {
        enum Call: Equatable {
            case permission(MediaPlayer, ask: Bool)
            case send(PlaybackCommand, MediaPlayer)
            case read(MediaPlayer)
        }

        private(set) var calls: [Call] = []
        private let permissionResult: AppleEventOutcome
        private let current: NowPlayingInfo?

        init(permission: AppleEventOutcome = .ok, current: NowPlayingInfo? = nil) {
            permissionResult = permission
            self.current = current
        }

        func permission(for player: MediaPlayer, pid: pid_t, ask: Bool) async -> AppleEventOutcome {
            calls.append(.permission(player, ask: ask))
            return permissionResult
        }

        func send(_ command: PlaybackCommand, to player: MediaPlayer, pid: pid_t) async -> AppleEventOutcome {
            calls.append(.send(command, player))
            return .ok
        }

        func readCurrent(of player: MediaPlayer, pid: pid_t) async -> NowPlayingInfo? {
            calls.append(.read(player))
            return current
        }
    }

    private func makeSource(_ sender: FakeSender, running: Set<MediaPlayer>) -> ScriptablePlayersSource {
        ScriptablePlayersSource(sender: sender, runningPID: { running.contains($0) ? 4242 : nil })
    }

    private func waitForCalls(_ sender: FakeSender, count: Int) async {
        for _ in 0..<1000 where await sender.calls.count < count { await Task.yield() }
    }

    // MARK: Commands

    func testCommandToAPlayerThatIsNotRunningSendsNothing() async {
        let sender = FakeSender()
        let outcome = await makeSource(sender, running: []).send(.playPause, to: .spotify)
        XCTAssertEqual(outcome, .notRunning)
        let calls = await sender.calls
        XCTAssertEqual(calls, [])
    }

    func testCommandAsksForPermissionThenSends() async {
        let sender = FakeSender()
        let outcome = await makeSource(sender, running: [.music]).send(.next, to: .music)
        XCTAssertEqual(outcome, .ok)
        let calls = await sender.calls
        XCTAssertEqual(calls, [.permission(.music, ask: true), .send(.next, .music)])
    }

    func testDeniedCommandIsNotSent() async {
        let sender = FakeSender(permission: .denied)
        let outcome = await makeSource(sender, running: [.spotify]).send(.playPause, to: .spotify)
        XCTAssertEqual(outcome, .denied)
        let calls = await sender.calls
        XCTAssertEqual(calls, [.permission(.spotify, ask: true)])
    }

    // MARK: Start

    func testStartReadsTheCurrentTrackOnlyWithASilentCheck() async {
        let playing = NowPlayingInfo(player: .spotify, state: .playing, title: "Song", artist: "Band")
        let sender = FakeSender(permission: .ok, current: playing)
        let source = makeSource(sender, running: [.spotify])
        var updates = source.updates.makeAsyncIterator()
        let first = await updates.next()
        XCTAssertEqual(first, NowPlayingInfo(player: .spotify, state: .unknown))
        let second = await updates.next()
        XCTAssertEqual(second, playing)
        let calls = await sender.calls
        XCTAssertEqual(calls, [.permission(.spotify, ask: false), .read(.spotify)])
    }

    func testStartWithoutPermissionNeverReadsOrPrompts() async {
        let sender = FakeSender(permission: .needsConsent)
        let source = makeSource(sender, running: [.music, .spotify])
        var updates = source.updates.makeAsyncIterator()
        let first = await updates.next()
        XCTAssertEqual(first, NowPlayingInfo(player: .music, state: .unknown))
        await waitForCalls(sender, count: 2)
        let calls = await sender.calls
        XCTAssertEqual(Set(calls.map { "\($0)" }),
                       ["\(FakeSender.Call.permission(.music, ask: false))", "\(FakeSender.Call.permission(.spotify, ask: false))"])
    }

    func testNothingRunningAtStartSendsNothing() async {
        let sender = FakeSender()
        let source = makeSource(sender, running: [])
        _ = source.updates
        source.receive(NowPlayingInfo(player: .music, state: .playing, title: "Song"), carriesTrack: true)
        for _ in 0..<50 { await Task.yield() }
        let calls = await sender.calls
        XCTAssertEqual(calls, [])
    }

    // MARK: Notifications, launch and quit

    func testNotificationsLaunchAndQuitDriveTheStream() async {
        let source = makeSource(FakeSender(), running: [])
        var updates = source.updates.makeAsyncIterator()
        source.playerRunningChanged(.spotify, isRunning: true)
        var next = await updates.next()
        XCTAssertEqual(next, NowPlayingInfo(player: .spotify, state: .unknown))

        source.receive(NowPlayingInfo(player: .spotify, state: .playing, title: "Song"), carriesTrack: true)
        // An identical repeat (Music does this) yields nothing, so the next value is the pause.
        source.receive(NowPlayingInfo(player: .spotify, state: .playing, title: "Song"), carriesTrack: true)
        source.receive(NowPlayingInfo(player: .spotify, state: .paused), carriesTrack: false)
        next = await updates.next()
        XCTAssertEqual(next, NowPlayingInfo(player: .spotify, state: .playing, title: "Song"))
        next = await updates.next()
        XCTAssertEqual(next, NowPlayingInfo(player: .spotify, state: .paused, title: "Song"))

        source.playerRunningChanged(.spotify, isRunning: false)
        next = await updates.next()
        XCTAssertEqual(next, .some(nil))
    }

    func testEndingTheStreamRemovesTheObservers() async {
        let source = makeSource(FakeSender(), running: [])
        let consumer = Task { for await _ in source.updates {} }
        for _ in 0..<1000 where !source.isObserving { await Task.yield() }
        XCTAssertTrue(source.isObserving)
        consumer.cancel()
        for _ in 0..<1000 where source.isObserving { await Task.yield() }
        XCTAssertFalse(source.isObserving)
    }

    func testANewStreamReplacesTheOldOneAndALateEndDoesNotStopIt() async {
        let source = makeSource(FakeSender(), running: [])
        let old = Task { for await _ in source.updates {} }
        for _ in 0..<50 { await Task.yield() }
        var updates = source.updates.makeAsyncIterator()
        old.cancel()
        for _ in 0..<50 { await Task.yield() }
        XCTAssertTrue(source.isObserving)
        source.playerRunningChanged(.music, isRunning: true)
        let next = await updates.next()
        XCTAssertEqual(next, NowPlayingInfo(player: .music, state: .unknown))
    }
}
