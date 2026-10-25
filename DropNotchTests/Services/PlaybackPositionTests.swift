import XCTest
@testable import DropNotch

final class PlaybackPositionTests: XCTestCase {
    private let anchor = Date(timeIntervalSinceReferenceDate: 1_000)

    func testMovesOnlyWhilePlaying() {
        let position = PlaybackPosition(seconds: 60, at: anchor)
        let later = anchor.addingTimeInterval(5)
        XCTAssertEqual(position.elapsed(at: later, isPlaying: true, duration: 200), 65)
        XCTAssertEqual(position.elapsed(at: later, isPlaying: false, duration: 200), 60)
    }

    func testStopsAtTheEndOfTheTrack() {
        let position = PlaybackPosition(seconds: 195, at: anchor)
        XCTAssertEqual(position.elapsed(at: anchor.addingTimeInterval(30), isPlaying: true, duration: 200), 200)
    }

    func testUnknownDurationDoesNotClamp() {
        let position = PlaybackPosition(seconds: 195, at: anchor)
        XCTAssertEqual(position.elapsed(at: anchor.addingTimeInterval(30), isPlaying: true, duration: nil), 225)
    }

    func testAClockThatWentBackwardsDoesNotRewind() {
        let position = PlaybackPosition(seconds: 60, at: anchor)
        XCTAssertEqual(position.elapsed(at: anchor.addingTimeInterval(-10), isPlaying: true, duration: 200), 60)
    }

    func testNeverNegative() {
        let position = PlaybackPosition(seconds: -3, at: anchor)
        XCTAssertEqual(position.elapsed(at: anchor, isPlaying: false, duration: 200), 0)
    }

    func testInfoElapsedUsesItsStateAndDuration() {
        var info = NowPlayingInfo(player: .music, state: .playing, duration: 100,
                                  position: PlaybackPosition(seconds: 90, at: anchor))
        XCTAssertEqual(info.elapsed(at: anchor.addingTimeInterval(20)), 100)
        info.state = .paused
        XCTAssertEqual(info.elapsed(at: anchor.addingTimeInterval(20)), 90)
        info.position = nil
        XCTAssertNil(info.elapsed(at: anchor))
    }
}
