import XCTest
@testable import DropNotch

@MainActor
final class NowPlayingLyricsTests: XCTestCase {
    private final class FakePlayers: NowPlayingSource {
        let stream: AsyncStream<NowPlayingInfo?>
        init(stream: AsyncStream<NowPlayingInfo?>) { self.stream = stream }
        var updates: AsyncStream<NowPlayingInfo?> { stream }
        func send(_ command: PlaybackCommand, to player: MediaPlayer) async -> AppleEventOutcome { .ok }
        func refresh(_ player: MediaPlayer) {}
    }

    private final class FakeLyrics: LyricsSource, @unchecked Sendable {
        var requests: [String] = []
        var fails = false
        func lyrics(title: String, artist: String, duration: TimeInterval?) async throws -> SyncedLyrics? {
            requests.append(title)
            if fails { throw ServiceError.badResponse(status: 500) }
            return title == "Instrumental" ? nil : SyncedLyrics(lrc: "[00:01.00] Line of \(title)")
        }
    }

    private var suites: [String] = []

    private func makeDefaults(lyricsOn: Bool) -> UserDefaults {
        let name = "NowPlayingLyricsTests.\(UUID())"
        suites.append(name)
        let defaults = UserDefaults(suiteName: name)!
        defaults.set(lyricsOn, forKey: LRCLibClient.enabledKey)
        return defaults
    }

    override func tearDown() {
        suites.forEach { UserDefaults(suiteName: $0)?.removePersistentDomain(forName: $0) }
        suites = []
        super.tearDown()
    }

    private func track(_ id: String, title: String = "Song") -> NowPlayingInfo {
        NowPlayingInfo(player: .music, state: .playing, title: title, artist: "Band", trackID: id, duration: 180,
                       position: PlaybackPosition(seconds: 0, at: Date()))
    }

    /// A started module showing `info`, and the continuation that feeds it.
    private func module(lyrics: FakeLyrics, on: Bool, showing info: NowPlayingInfo)
        async -> (NowPlayingModule, AsyncStream<NowPlayingInfo?>.Continuation) {
        let (stream, continuation) = AsyncStream.makeStream(of: NowPlayingInfo?.self)
        let module = NowPlayingModule(source: FakePlayers(stream: stream), lyricsSource: lyrics,
                                      defaults: makeDefaults(lyricsOn: on))
        module.start()
        continuation.yield(info)
        for _ in 0..<1000 where module.shown == nil { await Task.yield() }
        return (module, continuation)
    }

    func testOffByDefaultSendsNothing() async {
        let lyrics = FakeLyrics()
        let (module, _) = await module(lyrics: lyrics, on: false, showing: track("A"))
        await module.loadLyrics()
        XCTAssertNil(module.lyrics)
        XCTAssertTrue(lyrics.requests.isEmpty)
        XCTAssertFalse(NowPlayingModule(source: FakePlayers(stream: AsyncStream { _ in })).lyricsEnabled,
                       "no lyrics source, no lyrics")
    }

    func testOneRequestPerTrackPerSession() async {
        let lyrics = FakeLyrics()
        let (module, continuation) = await module(lyrics: lyrics, on: true, showing: track("A", title: "First"))
        await module.loadLyrics()
        XCTAssertEqual(module.lyrics?.trackID, "A")
        XCTAssertEqual(module.lyrics?.lyrics.lines.first?.text, "Line of First")
        await module.loadLyrics()
        continuation.yield(track("B", title: "Instrumental"))
        for _ in 0..<1000 where module.shown?.trackID != "B" { await Task.yield() }
        await module.loadLyrics()
        XCTAssertNil(module.lyrics, "none found for B")
        continuation.yield(track("A", title: "First"))
        for _ in 0..<1000 where module.shown?.trackID != "A" { await Task.yield() }
        await module.loadLyrics()
        XCTAssertEqual(module.lyrics?.trackID, "A")
        await module.loadLyrics()
        XCTAssertEqual(lyrics.requests, ["First", "Instrumental"], "A and B once each, from the cache after")
    }

    func testFailuresAreNotCachedAndStopForgetsEverything() async {
        let lyrics = FakeLyrics()
        lyrics.fails = true
        let (module, continuation) = await module(lyrics: lyrics, on: true, showing: track("A"))
        await module.loadLyrics()
        XCTAssertNil(module.lyrics)
        lyrics.fails = false
        await module.loadLyrics()
        XCTAssertNotNil(module.lyrics, "tried again after a failure")
        module.stop()
        XCTAssertNil(module.lyrics)
        continuation.finish()
    }
}
