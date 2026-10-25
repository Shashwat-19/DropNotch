import XCTest
@testable import DropNotch

@MainActor
final class NoNowPlayingSourceTests: XCTestCase {
    func testCommandsGoNowhere() async {
        let source = NoNowPlayingSource()
        for player in MediaPlayer.allCases {
            let outcome = await source.send(.playPause, to: player)
            XCTAssertEqual(outcome, .notRunning)
        }
    }
}
