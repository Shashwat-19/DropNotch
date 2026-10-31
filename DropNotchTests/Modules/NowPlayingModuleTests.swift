import AppKit
import XCTest
@testable import DropNotch

@MainActor
final class NowPlayingModuleTests: XCTestCase {
    private final class FakeSource: NowPlayingSource {
        var stream: AsyncStream<NowPlayingInfo?>
        /// Feeds `stream` once `start(_:_:showing:)` has made it.
        var continuation: AsyncStream<NowPlayingInfo?>.Continuation?
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
    /// `settleDelay` and `artworkHold` default to longer than any test, so a click only settles, and a held
    /// artwork only expires, when a test asks for it.
    private func moduleShowing(_ info: NowPlayingInfo, settleDelay: Duration = .seconds(600),
                               artworkHold: Duration = .seconds(600)) async -> (NowPlayingModule, FakeSource) {
        let source = FakeSource(stream: AsyncStream { _ in })
        let module = NowPlayingModule(source: source, settleDelay: settleDelay, artworkHold: artworkHold)
        await start(module, source, showing: info)
        return (module, source)
    }

    /// Gives the source a fresh stream (a cancelled consumer ends the old one), starts and shows `info`.
    private func start(_ module: NowPlayingModule, _ source: FakeSource, showing info: NowPlayingInfo) async {
        let (stream, continuation) = AsyncStream.makeStream(of: NowPlayingInfo?.self)
        source.stream = stream
        source.continuation = continuation
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

    /// Sends `info` as the player's next update and returns once the module shows it.
    private func deliver(_ info: NowPlayingInfo?, to module: NowPlayingModule, _ source: FakeSource) async {
        source.continuation?.yield(info)
        for _ in 0..<1000 where module.info != info { await Task.yield() }
        XCTAssertEqual(module.info, info, "the update never arrived")
    }

    // MARK: Optimistic play/pause

    func testPlayPauseFlipsAtOnceBeforeTheSendReturns() async {
        let (module, source) = await moduleShowing(NowPlayingInfo(player: .music, state: .paused))
        source.holdsReplies = true
        let play = await clickInFlight(module, source, .playPause)
        XCTAssertEqual(module.pendingIsPlaying, true)
        XCTAssertTrue(module.isPlaying)
        source.release(.ok)
        await play.value

        await deliver(NowPlayingInfo(player: .music, state: .playing), to: module, source)
        let pause = await clickInFlight(module, source, .playPause)
        XCTAssertEqual(module.pendingIsPlaying, false)
        XCTAssertFalse(module.isPlaying)
        source.release(.ok)
        await pause.value
    }

    // Music sends a burst of stale notifications after a click (D24).
    func testBeforeTheSendReturnsOnlyAnAgreeingUpdateConfirmsTheClick() async {
        let (module, source) = await moduleShowing(NowPlayingInfo(player: .music, state: .playing, title: "a"))
        source.holdsReplies = true
        let click = await clickInFlight(module, source, .playPause)

        await deliver(NowPlayingInfo(player: .music, state: .playing, title: "b"), to: module, source)
        XCTAssertEqual(module.pendingIsPlaying, false, "a stale update must not undo the click")
        XCTAssertFalse(module.isPlaying)

        await deliver(NowPlayingInfo(player: .music, state: .paused, title: "b"), to: module, source)
        XCTAssertNil(module.pendingIsPlaying)
        XCTAssertFalse(module.isPlaying)

        source.release(.ok)
        await click.value
        XCTAssertNil(module.pendingIsPlaying)
        XCTAssertFalse(module.isPlaying)
    }

    func testAFailedSendRevertsAtOnce() async {
        for outcome in [AppleEventOutcome.denied, .timedOut, .notRunning, .needsConsent, .failed(-1)] {
            let (module, source) = await moduleShowing(NowPlayingInfo(player: .music, state: .paused))
            source.holdsReplies = true
            let click = await clickInFlight(module, source, .playPause)
            XCTAssertTrue(module.isPlaying)
            source.release(outcome)
            await click.value
            XCTAssertNil(module.pendingIsPlaying, "\(outcome)")
            XCTAssertFalse(module.isPlaying, "\(outcome)")
            XCTAssertEqual(source.refreshed, [], "\(outcome)")
        }
    }

    // Part of a Music burst can land after the reply (D24): it must not undo the click either.
    func testAfterAnOKReplyADisagreeingUpdateStillWaits() async {
        let (module, source) = await moduleShowing(NowPlayingInfo(player: .music, state: .paused, title: "a"))
        await module.perform(.playPause)
        await deliver(NowPlayingInfo(player: .music, state: .paused, title: "b"), to: module, source)
        XCTAssertEqual(module.pendingIsPlaying, true)
        XCTAssertTrue(module.isPlaying)
    }

    // A command that changed nothing sends no notification: the player's own state comes back after the delay.
    func testAClickThePlayerNeverConfirmsSettlesAfterTheDelay() async throws {
        let (module, _) = await moduleShowing(NowPlayingInfo(player: .spotify, state: .paused),
                                              settleDelay: .milliseconds(10))
        await module.perform(.playPause)
        XCTAssertTrue(module.isPlaying)
        for _ in 0..<100 where module.pendingIsPlaying != nil { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNil(module.pendingIsPlaying)
        XCTAssertFalse(module.isPlaying)
    }

    // Two quick clicks: the first click's late notification and its settle must not undo the second.
    func testAnEarlierClickCannotUndoALaterOne() async throws {
        let (module, source) = await moduleShowing(NowPlayingInfo(player: .music, state: .paused),
                                                   settleDelay: .milliseconds(10))
        await module.perform(.playPause)
        source.holdsReplies = true
        let second = await clickInFlight(module, source, .playPause)
        XCTAssertEqual(module.pendingIsPlaying, false)
        await deliver(NowPlayingInfo(player: .music, state: .playing), to: module, source)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(module.pendingIsPlaying, false, "the first click's update and settle came and went")
        source.release(.ok)
        await second.value
    }

    func testASkipStraightAfterDoesNotStopTheSettle() async throws {
        let (module, _) = await moduleShowing(NowPlayingInfo(player: .music, state: .paused),
                                              settleDelay: .milliseconds(10))
        await module.perform(.playPause)
        await module.perform(.next)
        for _ in 0..<100 where module.pendingIsPlaying != nil { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNil(module.pendingIsPlaying)
        XCTAssertFalse(module.isPlaying)
    }

    func testAFailedSkipKeepsAConfirmedPlayPausePending() async {
        let (module, source) = await moduleShowing(NowPlayingInfo(player: .music, state: .paused))
        await module.perform(.playPause)
        source.outcome = .timedOut
        await module.perform(.next)
        XCTAssertEqual(module.pendingIsPlaying, true)
    }

    // No notification and no grant yet: the first click may bring up the Automation prompt, and the state
    // is only a guess, so nothing flips.
    func testAnUnknownStateDoesNotFlip() async {
        let (module, source) = await moduleShowing(NowPlayingInfo(player: .music, state: .unknown))
        source.holdsReplies = true
        let click = await clickInFlight(module, source, .playPause)
        XCTAssertNil(module.pendingIsPlaying)
        XCTAssertFalse(module.isPlaying)
        source.release(.ok)
        await click.value
    }

    func testOtherCommandsNeverSetPending() async {
        for command in [PlaybackCommand.next, .previous, .seek(to: 30)] {
            let (module, source) = await moduleShowing(NowPlayingInfo(player: .music, state: .playing))
            source.holdsReplies = true
            let click = await clickInFlight(module, source, command)
            XCTAssertNil(module.pendingIsPlaying, "\(command) in flight")
            source.release(.ok)
            await click.value
            XCTAssertNil(module.pendingIsPlaying, "\(command) returned")
            XCTAssertTrue(module.isPlaying)
            XCTAssertEqual(source.refreshed, [], "\(command)")
        }
    }

    func testStopClearsPending() async {
        let (module, source) = await moduleShowing(NowPlayingInfo(player: .music, state: .paused))
        source.holdsReplies = true
        let click = await clickInFlight(module, source, .playPause)
        module.stop()
        XCTAssertNil(module.pendingIsPlaying)
        XCTAssertFalse(module.isPlaying)
        source.release(.ok)
        await click.value
    }

    func testAPlayerChangeClearsPending() async {
        for next in [NowPlayingInfo(player: .spotify, state: .paused), nil] {
            let (module, source) = await moduleShowing(NowPlayingInfo(player: .music, state: .paused))
            source.holdsReplies = true
            let click = await clickInFlight(module, source, .playPause)
            XCTAssertEqual(module.pendingIsPlaying, true)
            await deliver(next, to: module, source)
            XCTAssertNil(module.pendingIsPlaying, "\(String(describing: next))")
            XCTAssertFalse(module.isPlaying, "\(String(describing: next))")
            source.release(.ok)
            await click.value
        }
    }

    func testAPlayPauseReplyAfterStopSetsNothing() async {
        let (module, source) = await moduleShowing(NowPlayingInfo(player: .music, state: .paused))
        source.holdsReplies = true
        let click = await clickInFlight(module, source, .playPause)
        module.stop()
        await start(module, source, showing: NowPlayingInfo(player: .music, state: .paused, title: "a"))
        source.release(.ok)
        await click.value
        XCTAssertNil(module.pendingIsPlaying)
        XCTAssertFalse(module.isPlaying)
        XCTAssertFalse(module.isSending)
        XCTAssertEqual(source.refreshed, [], "the old reply must not refresh")
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

    // MARK: D27: what the view draws (`shown`)

    /// Music track `id` in `state`, at `seconds` now, as the selection anchors it for each notification and read.
    private func music(_ state: NowPlayingInfo.State, at seconds: TimeInterval?, id: String? = "T",
                       artwork: NowPlayingArtwork? = nil, missing: Bool = false) -> NowPlayingInfo {
        NowPlayingInfo(player: .music, state: state, title: "t", trackID: id, duration: 200,
                       position: seconds.map { PlaybackPosition(seconds: $0, at: Date()) }, artwork: artwork,
                       artworkMissing: missing)
    }

    /// Where `shown` has got to by now.
    private func shownSeconds(_ module: NowPlayingModule) -> TimeInterval? { module.shown?.elapsed(at: Date()) }

    private func artwork(_ id: String) throws -> NowPlayingArtwork {
        let rep = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 4, bitsPerSample: 8,
                                                 samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let data = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        return try XCTUnwrap(NowPlayingArtwork(trackID: id, data: data))
    }

    // Clip (a), Music: 0:04 -> 0:00 -> 0:00 -> 0:00 -> 0:04 while clicking play/pause. Each click brings Music's
    // burst: the old state, then the new one, same track, positions anchored by the selection; then a read a
    // few tenths behind.
    func testClipAPauseFreezesAtTheClickedPositionAndPlayResumesFromIt() async throws {
        let start = Date()
        let (module, source) = await moduleShowing(music(.playing, at: 4))
        let now = { 4 + Date().timeIntervalSince(start) } // where Music really is while playing
        source.holdsReplies = true

        let pause = await clickInFlight(module, source, .playPause)
        let frozen = try XCTUnwrap(module.shown?.position?.seconds)
        XCTAssertEqual(frozen, 4, accuracy: 0.1)
        XCTAssertEqual(module.shown?.state, .paused)
        let steps: [(String, NowPlayingInfo)] = [
            ("old state", music(.playing, at: now())),
            ("new state", music(.paused, at: now())),
            ("read 0.2 s behind", music(.paused, at: frozen - 0.2)),
        ]
        for (step, info) in steps {
            await deliver(info, to: module, source)
            XCTAssertEqual(module.shown?.state, .paused, step)
            XCTAssertEqual(shownSeconds(module), frozen, "paused: \(step) neither zeroes nor moves the time")
        }
        source.release(.ok)
        await pause.value
        XCTAssertEqual(shownSeconds(module), frozen)

        let play = await clickInFlight(module, source, .playPause)
        let resumedAt = Date()
        XCTAssertEqual(module.shown?.state, .playing)
        XCTAssertEqual(module.shown?.position?.seconds, frozen, "play resumes where the pause froze")
        // The selection anchors Music's paused position (the read's) until something says otherwise.
        for (step, info) in [("old state", music(.paused, at: frozen - 0.2)),
                             ("new state", music(.playing, at: frozen - 0.2)),
                             ("read 0.2 s behind", music(.playing, at: frozen - 0.2 + Date().timeIntervalSince(resumedAt)))] {
            await deliver(info, to: module, source)
            XCTAssertEqual(module.shown?.state, .playing, step)
            let seconds = try XCTUnwrap(shownSeconds(module), step)
            XCTAssertGreaterThanOrEqual(seconds, frozen, "\(step) went back")
            XCTAssertEqual(seconds, frozen + Date().timeIntervalSince(resumedAt), accuracy: 0.05, step)
        }
        source.release(.ok)
        await play.value
        XCTAssertEqual(module.shown?.state, .playing)
        XCTAssertNil(module.pendingIsPlaying)
    }

    // Clip (b), Music: 0:07 -> 0:09 -> 0:03. A stale burst (old state first) and then a read 0.3 s behind.
    func testClipBTheTimeNeverGoesBackOrRunsAheadOfRealTime() async throws {
        let start = Date()
        let (module, source) = await moduleShowing(music(.playing, at: 7))
        let real = { 7 + Date().timeIntervalSince(start) }
        var last = try XCTUnwrap(shownSeconds(module))
        for (step, info) in [("stale state", music(.paused, at: real())),
                             ("current state", music(.playing, at: real())),
                             ("read 0.3 s behind", music(.playing, at: real() - 0.3))] {
            await deliver(info, to: module, source)
            let seconds = try XCTUnwrap(shownSeconds(module), step)
            XCTAssertGreaterThanOrEqual(seconds, last, "\(step) went back")
            XCTAssertLessThanOrEqual(seconds, real(), "\(step) ran ahead of the time that passed")
            XCTAssertEqual(seconds, real(), accuracy: 0.05, step)
            last = seconds
        }
        XCTAssertEqual(module.shown?.state, .playing)
    }

    func testASeekMovesTheBarAtOnceBothWays() async throws {
        let (module, source) = await moduleShowing(music(.playing, at: 50))
        source.holdsReplies = true
        for target in [120.0, 5] {
            let seek = await clickInFlight(module, source, .seek(to: target))
            XCTAssertEqual(try XCTUnwrap(shownSeconds(module)), target, accuracy: 0.05, "before the reply")
            source.release(.ok)
            await seek.value
            await deliver(music(.playing, at: target), to: module, source) // the read after the seek (D26)
            XCTAssertEqual(try XCTUnwrap(shownSeconds(module)), target, accuracy: 0.05, "after the read")
        }
    }

    func testAFailedSeekGoesBackToThePlayersPosition() async throws {
        let start = Date()
        let (module, source) = await moduleShowing(music(.playing, at: 50))
        source.holdsReplies = true
        let seek = await clickInFlight(module, source, .seek(to: 120))
        source.release(.timedOut)
        await seek.value
        XCTAssertEqual(try XCTUnwrap(shownSeconds(module)), 50 + Date().timeIntervalSince(start), accuracy: 0.05)
    }

    // A move of a second or more is a seek in the player's own window: applied, backward or forward.
    func testAJumpOfASecondOrMoreIsApplied() async throws {
        for state in [NowPlayingInfo.State.playing, .paused] {
            let (module, source) = await moduleShowing(music(state, at: 50))
            for target in [48.5, 53, 10] {
                await deliver(music(state, at: target), to: module, source)
                XCTAssertEqual(try XCTUnwrap(shownSeconds(module)), target, accuracy: 0.05, "\(state) to \(target)")
            }
        }
    }

    func testANewTrackResetsThePosition() async throws {
        let (module, source) = await moduleShowing(music(.playing, at: 50))
        await deliver(music(.playing, at: 0.3, id: "U"), to: module, source)
        XCTAssertEqual(try XCTUnwrap(shownSeconds(module)), 0.3, accuracy: 0.05)
        await deliver(music(.playing, at: nil, id: "V"), to: module, source)
        XCTAssertNil(module.shown?.position, "a new track with no position yet has none")
    }

    func testAMissingPositionOnTheSameTrackKeepsShowns() async throws {
        let start = Date()
        let (module, source) = await moduleShowing(music(.playing, at: 30))
        await deliver(music(.playing, at: nil), to: module, source)
        XCTAssertEqual(try XCTUnwrap(shownSeconds(module)), 30 + Date().timeIntervalSince(start), accuracy: 0.05)

        let (paused, pausedSource) = await moduleShowing(music(.paused, at: 30))
        await deliver(music(.paused, at: nil), to: paused, pausedSource)
        XCTAssertEqual(shownSeconds(paused), 30)
    }

    func testAClickOnATrackThatChangesMeanwhileShowsTheNewTrack() async throws {
        let (module, source) = await moduleShowing(music(.playing, at: 50))
        source.holdsReplies = true
        let click = await clickInFlight(module, source, .playPause)
        await deliver(music(.playing, at: 0, id: "U"), to: module, source)
        XCTAssertNil(module.pendingIsPlaying)
        XCTAssertEqual(module.shown?.state, .playing)
        XCTAssertEqual(try XCTUnwrap(shownSeconds(module)), 0, accuracy: 0.05)
        source.release(.ok)
        await click.value
    }

    // A settle takes the player's word as it is, even backwards.
    func testASettleShowsThePlayersPosition() async throws {
        let (module, source) = await moduleShowing(music(.paused, at: 50), settleDelay: .milliseconds(10))
        await deliver(music(.paused, at: 49.7), to: module, source) // steadied away
        XCTAssertEqual(shownSeconds(module), 50)
        await module.perform(.playPause) // the player never confirms it
        for _ in 0..<100 where module.pendingIsPlaying != nil { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNil(module.pendingIsPlaying)
        XCTAssertEqual(module.shown?.state, .paused)
        XCTAssertEqual(try XCTUnwrap(shownSeconds(module)), 49.7, accuracy: 0.001)
    }

    // MARK: D27: artwork held across a track change

    func testTheLastArtworkIsHeldUntilTheNewOneArrives() async throws {
        let (a, b) = (try artwork("T"), try artwork("U"))
        let (module, source) = await moduleShowing(music(.playing, at: 10, artwork: a))
        await deliver(music(.playing, at: 0, id: "U"), to: module, source)
        XCTAssertNil(module.info?.artwork)
        XCTAssertEqual(module.shown?.artwork, a, "no artwork yet: the old one stays")
        await deliver(music(.paused, at: 0.1, id: "U"), to: module, source)
        XCTAssertEqual(module.shown?.artwork, a, "the hold outlasts a same-track update")
        await deliver(music(.paused, at: 0.1, id: "U", artwork: b), to: module, source)
        XCTAssertEqual(module.shown?.artwork, b, "replaced as soon as it arrives")
    }

    func testArtworkMissingShowsTheAppIconAtOnce() async throws {
        let (module, source) = await moduleShowing(music(.playing, at: 10, artwork: try artwork("T")))
        await deliver(music(.playing, at: 0, id: "U"), to: module, source)
        XCTAssertNotNil(module.shown?.artwork)
        await deliver(music(.playing, at: 0.1, id: "U", missing: true), to: module, source)
        XCTAssertNil(module.shown?.artwork)
    }

    func testTheHoldExpires() async throws {
        let (module, source) = await moduleShowing(music(.playing, at: 10, artwork: try artwork("T")),
                                                   artworkHold: .milliseconds(10))
        await deliver(music(.playing, at: 0, id: "U"), to: module, source)
        for _ in 0..<100 where module.shown?.artwork != nil { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNil(module.shown?.artwork)
        XCTAssertEqual(module.shown?.trackID, "U")
    }

    func testNoTrackIDOrAPlayerChangeDropsTheHold() async throws {
        let others = [music(.playing, at: 0, id: nil),
                      NowPlayingInfo(player: .spotify, state: .playing, title: "s", trackID: "S")]
        for next in others {
            let (module, source) = await moduleShowing(music(.playing, at: 10, artwork: try artwork("T")))
            await deliver(next, to: module, source)
            XCTAssertNil(module.shown?.artwork, "\(next)")
        }
    }

    // After stop() and a restart, a held artwork must not come back, nor fire into the new session.
    func testStopClearsTheHold() async throws {
        let (module, source) = await moduleShowing(music(.playing, at: 10, artwork: try artwork("T")),
                                                   artworkHold: .milliseconds(10))
        await deliver(music(.playing, at: 0, id: "U"), to: module, source)
        XCTAssertNotNil(module.shown?.artwork)
        module.stop()
        XCTAssertNil(module.shown)
        await start(module, source, showing: music(.playing, at: 0, id: "U"))
        XCTAssertNil(module.shown?.artwork)
        try await Task.sleep(for: .milliseconds(50)) // past the old hold
        XCTAssertNil(module.shown?.artwork)
        XCTAssertEqual(module.shown?.trackID, "U")
    }
}
