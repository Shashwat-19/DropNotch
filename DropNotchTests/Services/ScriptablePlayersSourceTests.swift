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
        private let sendResult: AppleEventOutcome
        private let current: NowPlayingInfo?
        /// When true, each read waits for `releaseRead`, oldest first, so a test can make a reply late.
        private let holdsReads: Bool
        private var heldReads: [CheckedContinuation<NowPlayingInfo?, Never>] = []

        init(permission: AppleEventOutcome = .ok, send: AppleEventOutcome = .ok,
             current: NowPlayingInfo? = nil, holdsReads: Bool = false) {
            permissionResult = permission
            sendResult = send
            self.current = current
            self.holdsReads = holdsReads
        }

        func releaseRead(with info: NowPlayingInfo?) {
            heldReads.removeFirst().resume(returning: info)
        }

        func permission(for player: MediaPlayer, pid: pid_t, ask: Bool) async -> AppleEventOutcome {
            calls.append(.permission(player, ask: ask))
            return permissionResult
        }

        func send(_ command: PlaybackCommand, to player: MediaPlayer, pid: pid_t) async -> AppleEventOutcome {
            calls.append(.send(command, player))
            return sendResult
        }

        func readCurrent(of player: MediaPlayer, pid: pid_t) async -> NowPlayingInfo? {
            calls.append(.read(player))
            guard holdsReads else { return current }
            return await withCheckedContinuation { heldReads.append($0) }
        }
    }

    private func makeSource(_ sender: FakeSender, running: Set<MediaPlayer>) -> ScriptablePlayersSource {
        ScriptablePlayersSource(sender: sender, runningPID: { running.contains($0) ? 4242 : nil }, observesSystem: false)
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

    // The player can quit between the permission check and the send; the send's own outcome comes back.
    func testAPermittedCommandReturnsTheSendsOwnOutcome() async {
        let sender = FakeSender(permission: .ok, send: .notRunning)
        let outcome = await makeSource(sender, running: [.music]).send(.playPause, to: .music)
        XCTAssertEqual(outcome, .notRunning)
        let calls = await sender.calls
        XCTAssertEqual(calls, [.permission(.music, ask: true), .send(.playPause, .music)])
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

    // MARK: Streams and generations

    func testEachReadOfUpdatesEndsThePreviousStream() async {
        let source = makeSource(FakeSender(), running: [])
        var old = source.updates.makeAsyncIterator()
        let new = source.updates
        let end = await old.next()
        XCTAssertTrue(end == nil, "the old stream finished instead of yielding")
        withExtendedLifetime(new) { XCTAssertTrue(source.isObserving) }
    }

    // A start read that answers after a newer subscription began must not land in the new one.
    func testALateStartReadFromAnOldStreamIsDropped() async {
        let sender = FakeSender(permission: .ok, holdsReads: true)
        let source = makeSource(sender, running: [.spotify])
        var old = source.updates.makeAsyncIterator()
        let oldFirst = await old.next()
        XCTAssertEqual(oldFirst, NowPlayingInfo(player: .spotify, state: .unknown))
        await waitForCalls(sender, count: 2)

        var updates = source.updates.makeAsyncIterator()
        // The new stream yields the same value again: it starts from scratch, not from the old stream's last value.
        let first = await updates.next()
        XCTAssertEqual(first, NowPlayingInfo(player: .spotify, state: .unknown))
        await waitForCalls(sender, count: 4)

        await sender.releaseRead(with: NowPlayingInfo(player: .spotify, state: .playing, title: "Old"))
        for _ in 0..<100 { await Task.yield() }
        let fresh = NowPlayingInfo(player: .spotify, state: .paused, title: "New")
        await sender.releaseRead(with: fresh)
        let next = await updates.next()
        XCTAssertEqual(next, fresh)
    }

    func testAStartReadThatFindsNoStateChangesNothing() async {
        let sender = FakeSender(permission: .ok, current: nil)
        let source = makeSource(sender, running: [.music])
        var updates = source.updates.makeAsyncIterator()
        let first = await updates.next()
        XCTAssertEqual(first, NowPlayingInfo(player: .music, state: .unknown))
        await waitForCalls(sender, count: 2)
        for _ in 0..<50 { await Task.yield() }
        source.receive(NowPlayingInfo(player: .music, state: .paused, title: "Song"), carriesTrack: true)
        let next = await updates.next()
        XCTAssertEqual(next, NowPlayingInfo(player: .music, state: .paused, title: "Song"))
    }

    func testNotificationsBeforeAnyStreamAreIgnored() async {
        let source = makeSource(FakeSender(), running: [])
        source.receive(NowPlayingInfo(player: .music, state: .playing, title: "Song"), carriesTrack: true)
        source.playerRunningChanged(.music, isRunning: true)
        var updates = source.updates.makeAsyncIterator()
        source.playerRunningChanged(.spotify, isRunning: true)
        let next = await updates.next()
        XCTAssertEqual(next, NowPlayingInfo(player: .spotify, state: .unknown))
    }

    func testANewStreamDoesNotKeepTheOldStreamsPlayers() async {
        let source = makeSource(FakeSender(), running: [])
        var old = source.updates.makeAsyncIterator()
        source.receive(NowPlayingInfo(player: .music, state: .playing, title: "Song"), carriesTrack: true)
        _ = await old.next()
        var updates = source.updates.makeAsyncIterator()
        source.playerRunningChanged(.spotify, isRunning: true)
        let next = await updates.next()
        XCTAssertEqual(next, NowPlayingInfo(player: .spotify, state: .unknown))
    }

    // MARK: Launch, quit and repeats

    func testTheSameTrackIsPublishedAgainAfterQuitAndRelaunch() async {
        let source = makeSource(FakeSender(), running: [])
        var updates = source.updates.makeAsyncIterator()
        let song = NowPlayingInfo(player: .spotify, state: .playing, title: "Song")
        var seen: [NowPlayingInfo?] = []
        for _ in 0..<2 {
            source.playerRunningChanged(.spotify, isRunning: true)
            source.receive(song, carriesTrack: true)
            source.playerRunningChanged(.spotify, isRunning: false)
            for _ in 0..<3 { seen.append(await updates.next() ?? nil) }
        }
        let unknown = NowPlayingInfo(player: .spotify, state: .unknown)
        XCTAssertEqual(seen, [unknown, song, nil, unknown, song, nil])
    }

    func testARepeatedQuitPublishesNothing() async {
        let source = makeSource(FakeSender(), running: [])
        var updates = source.updates.makeAsyncIterator()
        source.receive(NowPlayingInfo(player: .music, state: .paused, title: "Song"), carriesTrack: true)
        source.playerRunningChanged(.music, isRunning: false)
        source.playerRunningChanged(.music, isRunning: false)
        source.playerRunningChanged(.spotify, isRunning: true)
        var seen: [NowPlayingInfo?] = []
        for _ in 0..<3 { seen.append(await updates.next() ?? nil) }
        XCTAssertEqual(seen, [NowPlayingInfo(player: .music, state: .paused, title: "Song"), nil,
                              NowPlayingInfo(player: .spotify, state: .unknown)])
    }

    // A player's first notification can beat the NSWorkspace launch notice; the late notice must not wipe it.
    func testALateLaunchNoticeKeepsTheReportedTrack() async {
        let source = makeSource(FakeSender(), running: [])
        var updates = source.updates.makeAsyncIterator()
        source.receive(NowPlayingInfo(player: .spotify, state: .playing, title: "Song"), carriesTrack: true)
        source.playerRunningChanged(.spotify, isRunning: true)
        source.receive(NowPlayingInfo(player: .spotify, state: .paused), carriesTrack: false)
        var seen: [NowPlayingInfo?] = []
        for _ in 0..<2 { seen.append(await updates.next() ?? nil) }
        XCTAssertEqual(seen, [NowPlayingInfo(player: .spotify, state: .playing, title: "Song"),
                              NowPlayingInfo(player: .spotify, state: .paused, title: "Song")])
    }
}
