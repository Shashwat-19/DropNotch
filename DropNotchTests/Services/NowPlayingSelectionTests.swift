import AppKit
import XCTest
@testable import DropNotch

final class NowPlayingSelectionTests: XCTestCase {
    private var selection = NowPlayingSelection()

    private func report(_ player: MediaPlayer, _ state: NowPlayingInfo.State, _ title: String? = "t") {
        selection.report(NowPlayingInfo(player: player, state: state, title: title, artist: "a"), carriesTrack: true)
    }

    func testNothingRunningShowsNothing() {
        XCTAssertNil(selection.current)
    }

    func testRunningPlayerWithUnknownStateShowsWithNoTrack() {
        selection.launched(.spotify)
        XCTAssertEqual(selection.current, NowPlayingInfo(player: .spotify, state: .unknown))
    }

    func testBothUnknownShowsMusicFirst() {
        selection.launched(.spotify)
        selection.launched(.music)
        XCTAssertEqual(selection.current?.player, .music)
    }

    func testKnownStateBeatsUnknown() {
        selection.launched(.music)
        report(.spotify, .paused)
        XCTAssertEqual(selection.current?.player, .spotify)
    }

    func testMostRecentPlayingWins() {
        report(.music, .playing)
        report(.spotify, .playing)
        XCTAssertEqual(selection.current?.player, .spotify)
        report(.music, .playing)
        XCTAssertEqual(selection.current?.player, .music)
    }

    func testPlayingBeatsAMoreRecentPause() {
        report(.music, .playing)
        report(.spotify, .paused)
        XCTAssertEqual(selection.current?.player, .music)
    }

    // With nothing playing, the player just paused stays, even though the other reported more recently than its play.
    func testPausingDoesNotHandOver() {
        report(.spotify, .playing)
        report(.music, .paused)
        report(.spotify, .paused)
        XCTAssertEqual(selection.current?.player, .spotify)
        XCTAssertEqual(selection.current?.state, .paused)
    }

    func testQuitDropsThePlayer() {
        report(.music, .paused)
        report(.spotify, .playing)
        selection.quit(.spotify)
        XCTAssertEqual(selection.current?.player, .music)
        selection.quit(.music)
        XCTAssertNil(selection.current)
    }

    func testStateOnlyReportKeepsTheLastTrack() {
        report(.music, .playing, "Song")
        selection.report(NowPlayingInfo(player: .music, state: .stopped), carriesTrack: false)
        XCTAssertEqual(selection.current, NowPlayingInfo(player: .music, state: .stopped, title: "Song", artist: "a"))
    }

    func testTrackReportWithNoTitleClearsTheLastTitle() {
        report(.spotify, .playing, "Song")
        selection.report(NowPlayingInfo(player: .spotify, state: .playing), carriesTrack: true)
        XCTAssertNil(selection.current?.title)
    }

    func testRelaunchStartsUnknownWithNoOldTrack() {
        report(.music, .playing, "Song")
        selection.quit(.music)
        selection.launched(.music)
        XCTAssertEqual(selection.current, NowPlayingInfo(player: .music, state: .unknown))
    }

    func testFetchAppliesOnlyWhileStateIsUnknown() {
        selection.launched(.music)
        selection.fetched(NowPlayingInfo(player: .music, state: .paused, title: "Fetched"))
        XCTAssertEqual(selection.current?.title, "Fetched")

        selection.launched(.spotify)
        report(.spotify, .playing, "Notified")
        selection.fetched(NowPlayingInfo(player: .spotify, state: .paused, title: "Stale"))
        XCTAssertEqual(selection.current?.title, "Notified")
    }

    func testFetchAfterQuitIsDropped() {
        selection.launched(.music)
        selection.quit(.music)
        selection.fetched(NowPlayingInfo(player: .music, state: .playing))
        XCTAssertNil(selection.current)
    }

    // A first notification can arrive before NSWorkspace's launch notice; it shows, and the notice keeps it.
    func testReportFromAPlayerNotMarkedLaunchedShowsAndALaterLaunchKeepsIt() {
        report(.spotify, .playing, "Song")
        XCTAssertEqual(selection.current?.title, "Song")
        selection.launched(.spotify)
        XCTAssertEqual(selection.current, NowPlayingInfo(player: .spotify, state: .playing, title: "Song", artist: "a"))
    }

    func testStateOnlyReportFromAPlayerNotKnownToBeRunningIsIgnored() {
        selection.report(NowPlayingInfo(player: .music, state: .stopped), carriesTrack: false)
        XCTAssertNil(selection.current)
    }

    // Both players send a state-only payload on quit; it can arrive after NSWorkspace's quit notice.
    func testQuitNoticeArrivingAfterTheQuitDoesNotBringThePlayerBack() {
        report(.spotify, .playing, "Song")
        selection.quit(.spotify)
        selection.report(NowPlayingInfo(player: .spotify, state: .stopped), carriesTrack: false)
        XCTAssertNil(selection.current)
    }

    func testStateOnlyReportFromALaunchedPlayerWithNoTrackHasNoTitle() {
        selection.launched(.music)
        selection.report(NowPlayingInfo(player: .music, state: .stopped), carriesTrack: false)
        XCTAssertEqual(selection.current, NowPlayingInfo(player: .music, state: .stopped))
    }

    func testRepeatedQuitIsHarmless() {
        report(.music, .paused)
        selection.quit(.spotify)
        selection.quit(.music)
        selection.quit(.music)
        XCTAssertNil(selection.current)
        report(.music, .paused)
        XCTAssertEqual(selection.current?.player, .music)
    }

    func testFetchWithNoTrackShowsTheStateOnly() {
        selection.launched(.music)
        selection.fetched(NowPlayingInfo(player: .music, state: .playing))
        XCTAssertEqual(selection.current, NowPlayingInfo(player: .music, state: .playing))
    }

    // A fetch counts as a report, so a fetched Playing beats a paused player that reported earlier.
    func testFetchedPlayingTakesOverFromAPausedPlayer() {
        report(.spotify, .paused)
        selection.launched(.music)
        selection.fetched(NowPlayingInfo(player: .music, state: .playing, title: "Fetched"))
        XCTAssertEqual(selection.current?.player, .music)
    }

    func testFetchForAPlayerNeverLaunchedIsDropped() {
        selection.fetched(NowPlayingInfo(player: .spotify, state: .playing, title: "Song"))
        XCTAssertNil(selection.current)
    }

    // MARK: D26: track fields, re-anchoring and reads

    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000)

    private func spotifyTrack(_ id: String?, _ state: NowPlayingInfo.State, at seconds: TimeInterval?,
                              url: String? = nil) -> NowPlayingInfo {
        NowPlayingInfo(player: .spotify, state: state, title: "t", trackID: id, duration: 200,
                       position: seconds.map { PlaybackPosition(seconds: $0, at: t0) },
                       artworkURL: url.flatMap(URL.init(string:)))
    }

    func testStateOnlyReportKeepsTrackFieldsAndFreezesThePositionWhereItWas() {
        selection.report(spotifyTrack("a", .playing, at: 60, url: "https://i.scdn.co/image/x"), carriesTrack: true, at: t0)
        selection.report(NowPlayingInfo(player: .spotify, state: .paused), carriesTrack: false, at: t0.addingTimeInterval(5))
        let current = selection.current
        XCTAssertEqual(current?.trackID, "a")
        XCTAssertEqual(current?.duration, 200)
        XCTAssertEqual(current?.artworkURL, URL(string: "https://i.scdn.co/image/x"))
        XCTAssertEqual(current?.position, PlaybackPosition(seconds: 65, at: t0.addingTimeInterval(5)))
        XCTAssertEqual(current?.elapsed(at: t0.addingTimeInterval(60)), 65, "paused: the bar stays where it stopped")
    }

    func testSameTrackKeepsWhatThePayloadLacks() {
        selection.report(spotifyTrack("a", .playing, at: 10, url: "https://i.scdn.co/image/x"), carriesTrack: true, at: t0)
        // Music-style payload: same track, no position or URL.
        var next = spotifyTrack("a", .paused, at: nil)
        next.duration = nil
        selection.report(next, carriesTrack: true, at: t0.addingTimeInterval(3))
        XCTAssertEqual(selection.current?.position, PlaybackPosition(seconds: 13, at: t0.addingTimeInterval(3)))
        XCTAssertEqual(selection.current?.duration, 200)
        XCTAssertNotNil(selection.current?.artworkURL)
    }

    func testANewTrackDropsTheOldPositionAndArtworkURL() {
        selection.report(spotifyTrack("a", .playing, at: 10, url: "https://i.scdn.co/image/x"), carriesTrack: true, at: t0)
        selection.report(spotifyTrack("b", .playing, at: nil), carriesTrack: true, at: t0)
        XCTAssertNil(selection.current?.position)
        XCTAssertNil(selection.current?.artworkURL)
    }

    func testAReadMergesWhenNothingNewerArrived() {
        selection.report(spotifyTrack("a", .playing, at: nil), carriesTrack: true, at: t0)
        let stamp = selection.stamp(for: .spotify)
        selection.refreshed(spotifyTrack("a", .playing, at: 42, url: "https://i.scdn.co/image/x"), stamp: stamp)
        XCTAssertEqual(selection.current?.position, PlaybackPosition(seconds: 42, at: t0))
        XCTAssertEqual(selection.current?.artworkURL, URL(string: "https://i.scdn.co/image/x"))
    }

    func testAReadIsDroppedAfterANewerReportOrForAnotherTrack() {
        selection.report(spotifyTrack("a", .playing, at: nil), carriesTrack: true, at: t0)
        let stamp = selection.stamp(for: .spotify)
        selection.report(spotifyTrack("a", .paused, at: nil), carriesTrack: true, at: t0)
        selection.refreshed(spotifyTrack("a", .playing, at: 42), stamp: stamp)
        XCTAssertNil(selection.current?.position, "a newer report arrived while the read was out")

        let fresh = selection.stamp(for: .spotify)
        selection.refreshed(spotifyTrack("b", .playing, at: 42), stamp: fresh)
        XCTAssertNil(selection.current?.position, "the read was about another track")
    }

    func testAReadDoesNotChangeWhichPlayerIsShown() {
        report(.music, .playing)
        report(.spotify, .paused)
        selection.refreshed(NowPlayingInfo(player: .spotify, state: .playing, title: "t", artist: "a",
                                           position: PlaybackPosition(seconds: 1, at: t0)),
                            stamp: selection.stamp(for: .spotify))
        XCTAssertEqual(selection.current?.player, .music)
    }

    func testAReadForAPlayerThatQuitIsDropped() {
        selection.report(spotifyTrack("a", .playing, at: nil), carriesTrack: true, at: t0)
        let stamp = selection.stamp(for: .spotify)
        selection.quit(.spotify)
        selection.refreshed(spotifyTrack("a", .playing, at: 42), stamp: stamp)
        XCTAssertNil(selection.current)
    }

    // MARK: D26: artwork belongs to its track

    private func artwork(_ id: String) throws -> NowPlayingArtwork {
        let rep = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 4, bitsPerSample: 8,
                                                 samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        return try XCTUnwrap(NowPlayingArtwork(trackID: id, data: try XCTUnwrap(rep.representation(using: .png, properties: [:]))))
    }

    func testArtworkIsKeptForItsTrackThroughPausesAndRepeats() throws {
        selection.report(spotifyTrack("a", .playing, at: 0), carriesTrack: true, at: t0)
        let art = try artwork("a")
        selection.setArtwork(art, for: .spotify)
        selection.report(NowPlayingInfo(player: .spotify, state: .paused), carriesTrack: false, at: t0)
        selection.report(spotifyTrack("a", .playing, at: 5), carriesTrack: true, at: t0)
        XCTAssertEqual(selection.current?.artwork, art)
        selection.report(spotifyTrack("b", .playing, at: 0), carriesTrack: true, at: t0)
        XCTAssertNil(selection.current?.artwork, "a new track drops the old artwork")
    }

    func testArtworkForATrackThatIsNoLongerCurrentIsDropped() throws {
        selection.report(spotifyTrack("b", .playing, at: 0), carriesTrack: true, at: t0)
        selection.setArtwork(try artwork("a"), for: .spotify)
        XCTAssertNil(selection.current?.artwork)
        selection.quit(.spotify)
        selection.setArtwork(try artwork("b"), for: .spotify)
        XCTAssertNil(selection.current)
    }
}

