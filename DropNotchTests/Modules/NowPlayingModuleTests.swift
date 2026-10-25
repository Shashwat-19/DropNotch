import XCTest
@testable import DropNotch

@MainActor
final class NowPlayingModuleTests: XCTestCase {
    private struct FakeSource: NowPlayingSource {
        let stream: AsyncStream<NowPlayingInfo?>
        var updates: AsyncStream<NowPlayingInfo?> { stream }
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
}
