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
        continuation.yield(NowPlayingInfo(title: "t", artist: "a", isPlaying: true))
        for _ in 0..<100 where module.info == nil { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(module.hasCompactContent)
        module.stop()
        module.stop()
        XCTAssertNil(module.info)
        XCTAssertFalse(module.hasCompactContent)
    }
}
