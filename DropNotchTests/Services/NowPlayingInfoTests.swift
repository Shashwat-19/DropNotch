import XCTest
@testable import DropNotch

/// `NowPlayingInfo.steadied(after:at:)` (D27): pure, so every date here is explicit.
final class NowPlayingInfoTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000)
    private var now: Date { t0.addingTimeInterval(2) }

    /// Music track `id` in `state`, at `seconds` as of `t0`.
    private func track(_ state: NowPlayingInfo.State, at seconds: TimeInterval?, id: String? = "T",
                       player: MediaPlayer = .music) -> NowPlayingInfo {
        NowPlayingInfo(player: player, state: state, title: "t", trackID: id, duration: 200,
                       position: seconds.map { PlaybackPosition(seconds: $0, at: t0) })
    }

    // MARK: Not steadied

    func testWithNothingShownTheInfoIsTakenAsItIs() {
        let next = track(.playing, at: 3)
        XCTAssertEqual(next.steadied(after: nil, at: now), next)
    }

    func testAnotherPlayerTrackOrNoTrackIDIsTakenAsItIs() {
        let shown = track(.paused, at: 50)
        for next in [track(.paused, at: 49.8, player: .spotify), track(.paused, at: 49.8, id: "U"),
                     track(.paused, at: 49.8, id: nil)] {
            XCTAssertEqual(next.steadied(after: shown, at: now), next, "\(next)")
        }
        // Two infos without an id are not the same track either.
        let noID = track(.paused, at: 50, id: nil)
        XCTAssertEqual(track(.paused, at: 49.8, id: nil).steadied(after: noID, at: now), track(.paused, at: 49.8, id: nil))
    }

    func testAShownInfoWithNoPositionSteadiesNothing() {
        let next = track(.paused, at: 3)
        XCTAssertEqual(next.steadied(after: track(.paused, at: nil), at: now), next)
    }

    // A second or more either way is a seek in the player's window: applied, playing or paused.
    func testAJumpOfASecondOrMoreIsApplied() {
        for state in [NowPlayingInfo.State.playing, .paused] {
            let shown = track(state, at: 50)
            for seconds in [49.0, 45, 51, 120, 0] {
                let next = track(state, at: seconds)
                XCTAssertEqual(next.steadied(after: shown, at: now), next, "\(state) to \(seconds)")
            }
        }
    }

    // MARK: Steadied

    func testPausedAJitterIntoAnotherSecondStaysWhereItFroze() {
        let shown = track(.paused, at: 50.5)
        for seconds in [49.8, 49.51] {
            let steadied = track(.paused, at: seconds).steadied(after: shown, at: now)
            XCTAssertEqual(steadied.position, PlaybackPosition(seconds: 50.5, at: now), "\(seconds)")
            XCTAssertEqual(steadied.state, .paused)
        }
    }

    // The text doesn't change, so the read is taken: it resets any lead over the player at each pause.
    func testPausedAReadInTheSameWholeSecondIsTaken() {
        let shown = track(.paused, at: 50.5)
        for seconds in [50.0, 50.2, 50.99] {
            let next = track(.paused, at: seconds)
            XCTAssertEqual(next.steadied(after: shown, at: now), next, "\(seconds)")
        }
    }

    func testPlayingABackwardJitterCarriesOnFromShown() {
        let shown = track(.playing, at: 50) // at 52 by `now`
        let steadied = track(.playing, at: 49.7).steadied(after: shown, at: now) // 51.7 by `now`
        XCTAssertEqual(steadied.position, PlaybackPosition(seconds: 52, at: now))
        XCTAssertEqual(steadied.elapsed(at: now.addingTimeInterval(3)), 55)
    }

    // Moving ahead while playing is never held back: the read is newer than the view's estimate.
    func testPlayingAForwardDifferenceUnderASecondIsApplied() {
        let shown = track(.playing, at: 50)
        let next = track(.playing, at: 50.6)
        XCTAssertEqual(next.steadied(after: shown, at: now), next)
    }

    func testAMissingPositionOnTheSameTrackKeepsShowns() {
        let playing = track(.playing, at: nil).steadied(after: track(.playing, at: 50), at: now)
        XCTAssertEqual(playing.position, PlaybackPosition(seconds: 52, at: now))
        let paused = track(.paused, at: nil).steadied(after: track(.paused, at: 50), at: now)
        XCTAssertEqual(paused.position, PlaybackPosition(seconds: 50, at: now))
    }

    // Only the position is steadied: the state, title and everything else are the new info's.
    func testOnlyThePositionChanges() {
        var next = track(.paused, at: 51.8)
        next.title = "new"
        let steadied = next.steadied(after: track(.playing, at: 50), at: now)
        XCTAssertEqual(steadied.state, .paused)
        XCTAssertEqual(steadied.title, "new")
        XCTAssertEqual(steadied.position, PlaybackPosition(seconds: 52, at: now))
    }

    func testTheToleranceIsExclusive() {
        XCTAssertEqual(NowPlayingInfo.steadyTolerance, 1)
        let shown = track(.paused, at: 50)
        XCTAssertEqual(track(.paused, at: 49).steadied(after: shown, at: now), track(.paused, at: 49))
        XCTAssertEqual(track(.paused, at: 49.5).steadied(after: shown, at: now).position,
                       PlaybackPosition(seconds: 50, at: now))
    }

    // Steadying works on where each position has got to by `now`, not on the raw anchors.
    func testComparesWhereEachPositionIsByNow() {
        let shown = track(.playing, at: 50) // 52 by `now`
        let read = NowPlayingInfo(player: .music, state: .playing, title: "t", trackID: "T", duration: 200,
                                  position: PlaybackPosition(seconds: 51.8, at: now)) // anchored later, 0.2 s behind
        XCTAssertEqual(read.steadied(after: shown, at: now).position, PlaybackPosition(seconds: 52, at: now))
    }
}
