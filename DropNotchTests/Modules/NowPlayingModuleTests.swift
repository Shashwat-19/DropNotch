import XCTest
@testable import DropNotch

@MainActor
final class NowPlayingModuleTests: XCTestCase {
    private final class FakeSource: NowPlayingSource {
        var stream: AsyncStream<NowPlayingInfo?>
        var outcome = AppleEventOutcome.ok
        /// When true, each send waits for `release`, oldest first: a command in flight or a prompt that is up.
        var holdsReplies = false
        private(set) var sent: [String] = []
        private(set) var refreshed: [MediaPlayer] = []
        private var held: [CheckedContinuation<AppleEventOutcome, Never>] = []

        init(stream: AsyncStream<NowPlayingInfo?>) { self.stream = stream }

        var updates: AsyncStream<NowPlayingInfo?> { stream }
        var heldCount: Int { held.count }

        func refresh(_ player: MediaPlayer) { refreshed.append(player) }

        func send(_ command: PlaybackCommand, to player: MediaPlayer) async -> AppleEventOutcome {
            sent.append("\(command) \(player)")
            guard holdsReplies else { return outcome }
            return await withCheckedContinuation { held.append($0) }
        }

        func release(_ outcome: AppleEventOutcome) {
            held.removeFirst().resume(returning: outcome)
        }
    }

    /// A started module showing `info`, and its source.
    private func moduleShowing(_ info: NowPlayingInfo) async -> (NowPlayingModule, FakeSource) {
        let source = FakeSource(stream: AsyncStream { _ in })
        let module = NowPlayingModule(source: source)
        await start(module, source, showing: info)
        return (module, source)
    }

    /// Gives the source a fresh stream (a cancelled consumer ends the old one), starts and shows `info`.
    private func start(_ module: NowPlayingModule, _ source: FakeSource, showing info: NowPlayingInfo) async {
        let (stream, continuation) = AsyncStream.makeStream(of: NowPlayingInfo?.self)
        source.stream = stream
        module.start()
        continuation.yield(info)
        for _ in 0..<1000 where module.info == nil { await Task.yield() }
    }

    /// Starts a click and returns once its send is held in the source.
    private func clickInFlight(_ module: NowPlayingModule, _ source: FakeSource, _ command: PlaybackCommand)
        async -> Task<Void, Never> {
        let held = source.heldCount
        let click = Task { await module.perform(command) }
        for _ in 0..<1000 where source.heldCount == held { await Task.yield() }
        return click
    }

    func testStartConsumesUpdatesAndStopClearsThem() async throws {
        let (stream, continuation) = AsyncStream.makeStream(of: NowPlayingInfo?.self)
        let module = NowPlayingModule(source: FakeSource(stream: stream))
        XCTAssertFalse(module.hasCompactContent)
        module.start()
        continuation.yield(NowPlayingInfo(player: .music, state: .playing, title: "t", artist: "a"))
        for _ in 0..<100 where module.info == nil { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(module.hasCompactContent)
        module.stop()
        module.stop()
        XCTAssertNil(module.info)
        XCTAssertFalse(module.hasCompactContent)
    }

    // Cancelling the consuming task terminates the stream, which is observable without any sleeping.
    func testStopEndsStreamConsumptionSoLaterUpdatesAreIgnored() async throws {
        let (stream, continuation) = AsyncStream.makeStream(of: NowPlayingInfo?.self)
        let ended = expectation(description: "stream consumption ended")
        continuation.onTermination = { _ in ended.fulfill() }
        let module = NowPlayingModule(source: FakeSource(stream: stream))
        module.start()
        continuation.yield(NowPlayingInfo(player: .music, state: .playing, title: "t", artist: "a"))
        for _ in 0..<1000 where module.info == nil { await Task.yield() }
        XCTAssertNotNil(module.info)
        module.stop()
        await fulfillment(of: [ended], timeout: 5)
        continuation.yield(NowPlayingInfo(player: .music, state: .playing, title: "late", artist: "a"))
        for _ in 0..<50 { await Task.yield() }
        XCTAssertNil(module.info)
    }

    func testPerformSendsToThePlayerOnScreen() async {
        let (module, source) = await moduleShowing(NowPlayingInfo(player: .spotify, state: .playing))
        await module.perform(.next)
        XCTAssertEqual(source.sent, ["next spotify"])
        XCTAssertFalse(module.isSending)
    }

    func testPerformWithNothingOnScreenSendsNothing() async {
        let source = FakeSource(stream: AsyncStream { _ in })
        let module = NowPlayingModule(source: source)
        module.start()
        await module.perform(.playPause)
        XCTAssertEqual(source.sent, [])
    }

    func testDeniedShowsUntilAClickGetsThrough() async {
        let (module, source) = await moduleShowing(NowPlayingInfo(player: .music, state: .unknown))
        source.outcome = .denied
        await module.perform(.playPause)
        XCTAssertEqual(module.deniedPlayer, .music)
        source.outcome = .timedOut
        await module.perform(.playPause)
        XCTAssertEqual(module.deniedPlayer, .music, "only a click that gets through clears the denied state")
        source.outcome = .ok
        await module.perform(.playPause)
        XCTAssertNil(module.deniedPlayer)
    }

    func testStopClearsTheDeniedState() async {
        let (module, source) = await moduleShowing(NowPlayingInfo(player: .music, state: .paused))
        source.outcome = .denied
        await module.perform(.playPause)
        module.stop()
        XCTAssertNil(module.deniedPlayer)
        XCTAssertFalse(module.isSending)
    }

    // The view disables the controls while sending, but `perform` must hold the line itself too:
    // a second click while the Automation prompt is up must not queue a second event (D23).
    func testASecondClickWhileOneIsInFlightSendsNothing() async {
        let (module, source) = await moduleShowing(NowPlayingInfo(player: .spotify, state: .playing))
        source.holdsReplies = true
        let first = await clickInFlight(module, source, .next)
        XCTAssertTrue(module.isSending)

        await module.perform(.previous)
        XCTAssertEqual(source.sent, ["next spotify"])
        XCTAssertTrue(module.isSending)

        source.release(.ok)
        await first.value
        XCTAssertFalse(module.isSending)
        source.holdsReplies = false
        await module.perform(.previous)
        XCTAssertEqual(source.sent, ["next spotify", "previous spotify"])
    }

    // stop() clears the denied state; a reply that arrives after it must not bring it back.
    func testADeniedReplyAfterStopDoesNotComeBack() async {
        let (module, source) = await moduleShowing(NowPlayingInfo(player: .music, state: .paused))
        source.holdsReplies = true
        let click = await clickInFlight(module, source, .playPause)
        module.stop()
        source.release(.denied)
        await click.value
        XCTAssertNil(module.deniedPlayer)
    }

    // Disabling and re-enabling the module (ModuleRegistry.setEnabled) while a prompt is up, then
    // clicking again: the first click finishing must not re-enable the controls while the second waits.
    func testAnOldClickFinishingDoesNotEndANewClicksWait() async {
        let (module, source) = await moduleShowing(NowPlayingInfo(player: .music, state: .paused))
        source.holdsReplies = true
        let old = await clickInFlight(module, source, .playPause)
        module.stop()
        await start(module, source, showing: NowPlayingInfo(player: .music, state: .paused))
        XCTAssertNotNil(module.info)
        let new = await clickInFlight(module, source, .next)
        XCTAssertEqual(source.heldCount, 2)

        source.release(.ok)
        await old.value
        XCTAssertTrue(module.isSending, "the second click is still waiting for its reply")

        source.release(.ok)
        await new.value
        XCTAssertFalse(module.isSending)
    }

    func testOpeningReadsThePositionOfThePlayerOnScreen() async {
        let (module, source) = await moduleShowing(NowPlayingInfo(player: .spotify, state: .playing))
        module.didOpen()
        XCTAssertEqual(source.refreshed, [.spotify])
    }

    func testOpeningWithNothingOnScreenReadsNothing() {
        let source = FakeSource(stream: AsyncStream { _ in })
        let module = NowPlayingModule(source: source)
        module.didOpen()
        XCTAssertEqual(source.refreshed, [])
    }

    func testSeekGoesThroughTheSameClickPath() async {
        let (module, source) = await moduleShowing(NowPlayingInfo(player: .music, state: .playing))
        source.outcome = .denied
        await module.perform(.seek(to: 42))
        XCTAssertEqual(source.sent, ["seek(to: 42.0) music"])
        XCTAssertEqual(module.deniedPlayer, .music, "a refused seek shows the same System Settings link")
    }

    func testPointerPositionBecomesSecondsWithinTheTrack() {
        XCTAssertEqual(PlaybackProgressView.seconds(at: 50, width: 200, duration: 180), 45)
        XCTAssertEqual(PlaybackProgressView.seconds(at: -20, width: 200, duration: 180), 0)
        XCTAssertEqual(PlaybackProgressView.seconds(at: 260, width: 200, duration: 180), 180)
        XCTAssertEqual(PlaybackProgressView.seconds(at: 10, width: 0, duration: 180), 0)
    }
}

