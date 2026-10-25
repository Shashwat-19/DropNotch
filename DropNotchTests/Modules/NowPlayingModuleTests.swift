import XCTest
@testable import DropNotch

@MainActor
final class NowPlayingModuleTests: XCTestCase {
    private final class FakeSource: NowPlayingSource {
        let stream: AsyncStream<NowPlayingInfo?>
        var outcome = AppleEventOutcome.ok
        private(set) var sent: [String] = []

        init(stream: AsyncStream<NowPlayingInfo?>) { self.stream = stream }

        var updates: AsyncStream<NowPlayingInfo?> { stream }

        func send(_ command: PlaybackCommand, to player: MediaPlayer) async -> AppleEventOutcome {
            sent.append("\(command) \(player)")
            return outcome
        }
    }

    /// A started module showing `info`, and its source.
    private func moduleShowing(_ info: NowPlayingInfo) async -> (NowPlayingModule, FakeSource) {
        let (stream, continuation) = AsyncStream.makeStream(of: NowPlayingInfo?.self)
        let source = FakeSource(stream: stream)
        let module = NowPlayingModule(source: source)
        module.start()
        continuation.yield(info)
        for _ in 0..<1000 where module.info == nil { await Task.yield() }
        return (module, source)
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
}
