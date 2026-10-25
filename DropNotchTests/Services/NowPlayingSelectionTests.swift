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

    func testStateOnlyReportFromAPlayerWithNoTrackYetHasNoTitle() {
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
}
