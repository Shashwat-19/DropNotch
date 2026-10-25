import XCTest
@testable import DropNotch

// Payload shapes are the ones the probe saw (docs/research/now-playing-probe-2026-10-25.md).
final class PlayerNotificationParserTests: XCTestCase {
    func testFullPayloadGivesStateAndTrack() throws {
        let payload: [AnyHashable: Any] = ["Player State": "Playing", "Name": "Song", "Artist": "Band",
                                           "Album": "Record", "Total Time": 200_000]
        let result = try XCTUnwrap(PlayerNotificationParser.parse(payload, from: .music))
        XCTAssertEqual(result.info, NowPlayingInfo(player: .music, state: .playing, title: "Song", artist: "Band"))
        XCTAssertTrue(result.carriesTrack)
    }

    func testStateOnlyPayloadKeepsTheTrack() throws {
        for (raw, state) in [("Stopped", NowPlayingInfo.State.stopped), ("Paused", .paused), ("Playing", .playing)] {
            let result = try XCTUnwrap(PlayerNotificationParser.parse(["Player State": raw], from: .music))
            XCTAssertEqual(result.info, NowPlayingInfo(player: .music, state: state))
            XCTAssertFalse(result.carriesTrack, raw)
        }
    }

    func testSpotifyAdHasNoTitleOrArtistButReplacesTheTrack() throws {
        let payload: [AnyHashable: Any] = ["Player State": "Playing", "Name": "Buy now", "Artist": "Brand",
                                           "Track ID": "spotify:ad:000000012c1e4e8b0000002089b0a93e"]
        let result = try XCTUnwrap(PlayerNotificationParser.parse(payload, from: .spotify))
        XCTAssertEqual(result.info, NowPlayingInfo(player: .spotify, state: .playing))
        XCTAssertTrue(result.carriesTrack)
    }

    func testSpotifyTrackIsNotMistakenForAnAd() throws {
        let payload: [AnyHashable: Any] = ["Player State": "Paused", "Name": "Song", "Artist": "Band",
                                           "Track ID": "spotify:track:4uLU6hMCjMI75M1A2tKUQC"]
        let result = try XCTUnwrap(PlayerNotificationParser.parse(payload, from: .spotify))
        XCTAssertEqual(result.info.title, "Song")
    }

    func testEmptyOrOddTextBecomesNil() throws {
        let payload: [AnyHashable: Any] = ["Player State": "Playing", "Name": "  \n", "Artist": 42]
        let result = try XCTUnwrap(PlayerNotificationParser.parse(payload, from: .spotify))
        XCTAssertNil(result.info.title)
        XCTAssertNil(result.info.artist)
        XCTAssertTrue(result.carriesTrack)
    }

    func testTextIsTrimmed() throws {
        let result = try XCTUnwrap(PlayerNotificationParser.parse(["Player State": "Playing", "Name": " Song "], from: .music))
        XCTAssertEqual(result.info.title, "Song")
        XCTAssertNil(result.info.artist)
    }

    func testMissingOrUnknownStateIsIgnored() {
        XCTAssertNil(PlayerNotificationParser.parse(nil, from: .music))
        XCTAssertNil(PlayerNotificationParser.parse([:], from: .music))
        XCTAssertNil(PlayerNotificationParser.parse(["Name": "Song"], from: .music))
        XCTAssertNil(PlayerNotificationParser.parse(["Player State": "Rewinding"], from: .music))
        XCTAssertNil(PlayerNotificationParser.parse(["Player State": 1], from: .music))
    }
}
