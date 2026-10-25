import AppKit
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
            case artwork(MediaPlayer)
        }

        private(set) var calls: [Call] = []
        private let permissionResult: AppleEventOutcome
        private let sendResult: AppleEventOutcome
        private let current: NowPlayingInfo?
        private let artworkData: Data?
        /// When true, each read waits for `releaseRead`, oldest first, so a test can make a reply late.
        private let holdsReads: Bool
        private var heldReads: [CheckedContinuation<NowPlayingInfo?, Never>] = []

        init(permission: AppleEventOutcome = .ok, send: AppleEventOutcome = .ok,
             current: NowPlayingInfo? = nil, holdsReads: Bool = false, artwork: Data? = nil) {
            artworkData = artwork
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

        func readArtwork(of player: MediaPlayer, pid: pid_t) async -> Data? {
            calls.append(.artwork(player))
            return artworkData
        }

        func readCurrent(of player: MediaPlayer, pid: pid_t) async -> NowPlayingInfo? {
            calls.append(.read(player))
            guard holdsReads else { return current }
            return await withCheckedContinuation { heldReads.append($0) }
        }
    }

    /// Records each URL and answers with `data`. Never the network.
    private actor FakeArtworkLoader: ArtworkLoading {
        private(set) var urls: [URL] = []
        private let data: Data?
        init(data: Data? = nil) { self.data = data }
        func data(from url: URL) async -> Data? {
            urls.append(url)
            return data
        }
    }

    private func makeSource(_ sender: FakeSender, running: Set<MediaPlayer>,
                            loader: FakeArtworkLoader = FakeArtworkLoader()) -> ScriptablePlayersSource {
        ScriptablePlayersSource(sender: sender, artworkLoader: loader, runningPID: { running.contains($0) ? 4242 : nil },
                                observesSystem: false)
    }

    private static func png() -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 8, bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        return rep.representation(using: .png, properties: [:])!
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

    // MARK: D26: reads after notifications

    private func reads(_ sender: FakeSender) async -> [FakeSender.Call] {
        await sender.calls.filter { if case .read = $0 { true } else { false } }
    }

    func testMusicIsReadAfterEachNotificationThatCarriesATrack() async {
        let at = Date()
        let read = NowPlayingInfo(player: .music, state: .playing, title: "Song", trackID: "A1",
                                  duration: 180, position: PlaybackPosition(seconds: 70, at: at))
        let sender = FakeSender(current: read)
        let source = makeSource(sender, running: [.music])
        var updates = source.updates.makeAsyncIterator()
        _ = await updates.next() // unknown, from start
        await waitForCalls(sender, count: 2) // the start check and read
        source.receive(NowPlayingInfo(player: .music, state: .playing, title: "Song", trackID: "A1"), carriesTrack: true)
        source.receive(NowPlayingInfo(player: .music, state: .stopped), carriesTrack: false)
        source.receive(NowPlayingInfo(player: .music, state: .paused, title: "Song", trackID: "A1"), carriesTrack: true)
        await waitForCalls(sender, count: 6)
        let calls = await reads(sender)
        XCTAssertEqual(calls.count, 3, "start, and the two payloads with a track; not the state-only one")
    }

    func testSpotifyIsReadOncePerTrack() async {
        let sender = FakeSender()
        let source = makeSource(sender, running: [.spotify])
        let stream = source.updates // kept: a dropped stream ends observing
        await waitForCalls(sender, count: 2) // the start check and read
        for id in ["a", "a", "b", "b", "a"] {
            source.receive(NowPlayingInfo(player: .spotify, state: .playing, trackID: id), carriesTrack: true)
        }
        source.receive(NowPlayingInfo(player: .spotify, state: .playing), carriesTrack: true) // an ad: no id
        await waitForCalls(sender, count: 8)
        for _ in 0..<50 { await Task.yield() }
        let calls = await reads(sender)
        XCTAssertEqual(calls.count, 4, "start, then a, b and a again; never for a repeat or an ad")
        withExtendedLifetime(stream) {}
    }

    func testNoReadWithoutAnExistingGrant() async {
        let sender = FakeSender(permission: .needsConsent)
        let source = makeSource(sender, running: [.music])
        let stream = source.updates
        source.receive(NowPlayingInfo(player: .music, state: .playing, trackID: "A1"), carriesTrack: true)
        await waitForCalls(sender, count: 2)
        for _ in 0..<50 { await Task.yield() }
        let calls = await sender.calls
        XCTAssertEqual(calls, [.permission(.music, ask: false), .permission(.music, ask: false)])
        withExtendedLifetime(stream) {}
    }

    func testAReadMergesThePositionIntoTheStream() async {
        let at = Date()
        let read = NowPlayingInfo(player: .music, state: .playing, title: "Song", trackID: "A1",
                                  duration: 180, position: PlaybackPosition(seconds: 70, at: at))
        let sender = FakeSender(current: read)
        let source = makeSource(sender, running: [])
        var updates = source.updates.makeAsyncIterator()
        source.receive(NowPlayingInfo(player: .music, state: .playing, title: "Song", trackID: "A1"), carriesTrack: true)
        _ = await updates.next() // the notification itself
        source.refresh(.music) // not running: nothing happens
        let calls = await sender.calls
        XCTAssertEqual(calls, [])

        let running = makeSource(sender, running: [.music])
        var runningUpdates = running.updates.makeAsyncIterator()
        _ = await runningUpdates.next() // unknown, from start
        _ = await runningUpdates.next() // the start read
        running.receive(NowPlayingInfo(player: .music, state: .playing, title: "Song", trackID: "A1"), carriesTrack: true)
        // The notification re-anchors the start read's position at its own arrival; the read then lands.
        var latest = await runningUpdates.next()
        for _ in 0..<3 where latest??.position != read.position { latest = await runningUpdates.next() }
        XCTAssertEqual(latest??.position, PlaybackPosition(seconds: 70, at: at))
        XCTAssertEqual(latest??.duration, 180)
    }

    // MARK: D25/D26: artwork once per track

    private func nextWithArtwork(_ updates: inout AsyncStream<NowPlayingInfo?>.Iterator) async -> NowPlayingInfo? {
        for _ in 0..<6 {
            guard let value = await updates.next() else { return nil }
            if value?.artwork != nil { return value }
        }
        return nil
    }

    func testSpotifyArtworkIsFetchedOnceFromTheReadURL() async {
        let url = URL(string: "https://i.scdn.co/image/a")!
        let read = NowPlayingInfo(player: .spotify, state: .playing, title: "Song", trackID: "a", artworkURL: url)
        let loader = FakeArtworkLoader(data: Self.png())
        let source = makeSource(FakeSender(current: read), running: [.spotify], loader: loader)
        var updates = source.updates.makeAsyncIterator()
        let shown = await nextWithArtwork(&updates)
        XCTAssertEqual(shown?.artwork?.trackID, "a")
        source.receive(NowPlayingInfo(player: .spotify, state: .paused, title: "Song", trackID: "a"), carriesTrack: true)
        for _ in 0..<100 { await Task.yield() }
        let urls = await loader.urls
        XCTAssertEqual(urls, [url])
    }

    func testMusicArtworkIsReadFromMusicOncePerTrack() async {
        let read = NowPlayingInfo(player: .music, state: .playing, title: "Song", trackID: "A1")
        let sender = FakeSender(current: read, artwork: Self.png())
        let loader = FakeArtworkLoader()
        let source = makeSource(sender, running: [.music], loader: loader)
        var updates = source.updates.makeAsyncIterator()
        let shown = await nextWithArtwork(&updates)
        XCTAssertEqual(shown?.artwork?.trackID, "A1")
        source.receive(NowPlayingInfo(player: .music, state: .paused, title: "Song", trackID: "A1"), carriesTrack: true)
        for _ in 0..<100 { await Task.yield() }
        let artworkReads = await sender.calls.filter { $0 == .artwork(.music) }
        XCTAssertEqual(artworkReads.count, 1)
        let urls = await loader.urls
        XCTAssertEqual(urls, [], "Music artwork never touches the network")
    }

    func testAFailedFetchIsNotRetriedForTheSameTrack() async {
        let url = URL(string: "https://i.scdn.co/image/a")!
        let read = NowPlayingInfo(player: .spotify, state: .playing, title: "Song", trackID: "a", artworkURL: url)
        let loader = FakeArtworkLoader(data: nil)
        let source = makeSource(FakeSender(current: read), running: [.spotify], loader: loader)
        let stream = source.updates
        for _ in 0..<100 { await Task.yield() }
        source.receive(NowPlayingInfo(player: .spotify, state: .playing, title: "Song", trackID: "a"), carriesTrack: true)
        for _ in 0..<100 { await Task.yield() }
        let urls = await loader.urls
        XCTAssertEqual(urls, [url])
        withExtendedLifetime(stream) {}
    }

    func testNoArtworkWithoutAnExistingGrant() async {
        let loader = FakeArtworkLoader(data: Self.png())
        let sender = FakeSender(permission: .needsConsent, artwork: Self.png())
        let source = makeSource(sender, running: [.music, .spotify], loader: loader)
        let stream = source.updates
        source.receive(NowPlayingInfo(player: .spotify, state: .playing, trackID: "a"), carriesTrack: true)
        for _ in 0..<100 { await Task.yield() }
        let urls = await loader.urls
        XCTAssertEqual(urls, [])
        let artworkReads = await sender.calls.filter { $0 == .artwork(.music) }
        XCTAssertEqual(artworkReads, [])
        withExtendedLifetime(stream) {}
    }

    // MARK: D26: seek

    func testASuccessfulSeekReadsTheNewPosition() async {
        let sender = FakeSender()
        let source = makeSource(sender, running: [.spotify])
        let stream = source.updates
        await waitForCalls(sender, count: 2) // the start check and read
        let outcome = await source.send(.seek(to: 30), to: .spotify)
        XCTAssertEqual(outcome, .ok)
        await waitForCalls(sender, count: 6)
        let calls = await sender.calls.suffix(4)
        XCTAssertEqual(Array(calls), [.permission(.spotify, ask: true), .send(.seek(to: 30), .spotify),
                                      .permission(.spotify, ask: false), .read(.spotify)])
        withExtendedLifetime(stream) {}
    }

    func testAFailedSeekReadsNothing() async {
        let sender = FakeSender(send: .timedOut)
        let source = makeSource(sender, running: [.spotify])
        let stream = source.updates
        await waitForCalls(sender, count: 2)
        _ = await source.send(.seek(to: 30), to: .spotify)
        for _ in 0..<50 { await Task.yield() }
        let reads = await sender.calls.filter { $0 == .read(.spotify) }
        XCTAssertEqual(reads.count, 1, "only the start read")
        withExtendedLifetime(stream) {}
    }
}

