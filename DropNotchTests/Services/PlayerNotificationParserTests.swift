import XCTest
@testable import DropNotch

// Payload shapes are the ones the probe saw (docs/research/now-playing-probe-2026-10-25.md).
final class PlayerNotificationParserTests: XCTestCase {
    func testFullPayloadGivesStateAndTrack() throws {
        let payload: [AnyHashable: Any] = ["Player State": "Playing", "Name": "Song", "Artist": "Band",
                                           "Album": "Record", "Total Time": 200_000]
        let result = try XCTUnwrap(PlayerNotificationParser.parse(payload, from: .music))
        XCTAssertEqual(result.info, NowPlayingInfo(player: .music, state: .playing, title: "Song", artist: "Band",
                                                   duration: 200))
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

    // The read at start uses the same function, so it applies the same ad rule.
    func testSharedTrackRuleHidesAnAdAndKeepsARealTrack() {
        let ad = PlayerNotificationParser.track(.spotify, .playing, name: "Buy now", artist: "Brand",
                                                trackID: "spotify:ad:000000012c1e4e8b")
        XCTAssertEqual(ad, NowPlayingInfo(player: .spotify, state: .playing))
        let song = PlayerNotificationParser.track(.music, .paused, name: "Song", artist: " Band ", trackID: nil)
        XCTAssertEqual(song, NowPlayingInfo(player: .music, state: .paused, title: "Song", artist: "Band"))
    }

    // Only a string Track ID can mark an ad; anything else keeps the track.
    func testNonStringTrackIDIsNotAnAd() throws {
        let payload: [AnyHashable: Any] = ["Player State": "Playing", "Name": "Song", "Artist": "Band", "Track ID": 1234]
        let result = try XCTUnwrap(PlayerNotificationParser.parse(payload, from: .spotify))
        XCTAssertEqual(result.info, NowPlayingInfo(player: .spotify, state: .playing, title: "Song", artist: "Band"))
    }

    // A `Name` key that isn't a string still means "a track payload": it replaces the old title with none.
    func testNonStringNameCarriesATrackWithNoTitle() throws {
        let result = try XCTUnwrap(PlayerNotificationParser.parse(["Player State": "Paused", "Name": NSNull()], from: .music))
        XCTAssertEqual(result.info, NowPlayingInfo(player: .music, state: .paused))
        XCTAssertTrue(result.carriesTrack)
    }

    // Any local process can post these notifications, so text is capped.
    func testLongTextIsCapped() throws {
        let long = String(repeating: "a", count: 10_000)
        let result = try XCTUnwrap(PlayerNotificationParser.parse(["Player State": "Playing", "Name": "  " + long, "Artist": long],
                                                                  from: .music))
        XCTAssertEqual(result.info.title?.count, PlayerNotificationParser.maxTextLength)
        XCTAssertEqual(result.info.artist?.count, PlayerNotificationParser.maxTextLength)
    }

    // MARK: D26: ids, durations and positions (shapes and units from the media probe)

    func testMusicDurationIsMillisecondsAndIdIsUnsignedHex() throws {
        let payload: [AnyHashable: Any] = ["Player State": "Playing", "Name": "Song",
                                           "Total Time": NSNumber(value: Int64(182_109)),
                                           "PersistentID": NSNumber(value: Int64(-5_741_257_159_933_803_605))]
        let info = try XCTUnwrap(PlayerNotificationParser.parse(payload, from: .music)).info
        XCTAssertEqual(try XCTUnwrap(info.duration), 182.109, accuracy: 0.0001)
        XCTAssertEqual(info.trackID, String(format: "%016llX", UInt64(bitPattern: -5_741_257_159_933_803_605)))
        XCTAssertEqual(info.trackID?.count, 16)
        XCTAssertNil(info.position, "Music's notification has no position")
    }

    func testSpotifyDurationIsMillisecondsAndPositionIsSecondsAnchoredAtArrival() throws {
        let now = Date(timeIntervalSinceReferenceDate: 500)
        let payload: [AnyHashable: Any] = ["Player State": "Paused", "Name": "Song",
                                           "Duration": NSNumber(value: Int64(205_800)), "Playback Position": 68.758,
                                           "Track ID": "spotify:track:abc"]
        let info = try XCTUnwrap(PlayerNotificationParser.parse(payload, from: .spotify, at: now)).info
        XCTAssertEqual(info.duration, 205.8)
        XCTAssertEqual(info.position, PlaybackPosition(seconds: 68.758, at: now))
        XCTAssertEqual(info.trackID, "spotify:track:abc")
    }

    func testBadNumbersAreUnknownNotZero() {
        for bad: Any in ["123", Double.nan, Double.infinity, -1.0, NSNull()] {
            XCTAssertNil(PlayerNotificationParser.seconds(bad, unit: 1), "\(bad)")
        }
        XCTAssertNil(PlayerNotificationParser.seconds(nil, unit: 1000))
        XCTAssertEqual(PlayerNotificationParser.seconds(0, unit: 1000), 0)
    }

    func testMusicIdThatIsNotANumberIsUnknown() throws {
        let payload: [AnyHashable: Any] = ["Player State": "Playing", "Name": "Song", "PersistentID": "ABC"]
        XCTAssertNil(try XCTUnwrap(PlayerNotificationParser.parse(payload, from: .music)).info.trackID)
    }

    func testAnAdHasNoTrackIdButKeepsItsTiming() throws {
        let now = Date(timeIntervalSinceReferenceDate: 9)
        let payload: [AnyHashable: Any] = ["Player State": "Playing", "Name": "Buy", "Track ID": "spotify:ad:1",
                                           "Duration": 30_000, "Playback Position": 2.0]
        let info = try XCTUnwrap(PlayerNotificationParser.parse(payload, from: .spotify, at: now)).info
        XCTAssertNil(info.trackID)
        XCTAssertNil(info.title)
        XCTAssertEqual(info.duration, 30)
        XCTAssertEqual(info.position, PlaybackPosition(seconds: 2, at: now))
    }

    // MARK: D26: number shapes

    // Bridged payloads can carry Int, Int64 or Double NSNumbers for the same key.
    func testNumbersOfEitherShapeConvert() throws {
        let music: [AnyHashable: Any] = ["Player State": "Playing", "Name": "Song", "Total Time": 182_109.0]
        XCTAssertEqual(try XCTUnwrap(try XCTUnwrap(PlayerNotificationParser.parse(music, from: .music)).info.duration),
                       182.109, accuracy: 0.0001)
        let now = Date(timeIntervalSinceReferenceDate: 1)
        let spotify: [AnyHashable: Any] = ["Player State": "Playing", "Name": "Song", "Track ID": "spotify:track:x",
                                           "Duration": 205_800.0, "Playback Position": NSNumber(value: 68)]
        let info = try XCTUnwrap(PlayerNotificationParser.parse(spotify, from: .spotify, at: now)).info
        XCTAssertEqual(info.duration, 205.8)
        XCTAssertEqual(info.position, PlaybackPosition(seconds: 68, at: now))
    }

    // An id above Int64.max (bridged as UInt64) still reads as the same 16-digit hex.
    func testMusicIdAboveInt64MaxIsTheSameHex() {
        XCTAssertEqual(PlayerNotificationParser.musicTrackID(NSNumber(value: UInt64.max)), "FFFFFFFFFFFFFFFF")
        XCTAssertEqual(PlayerNotificationParser.musicTrackID(NSNumber(value: 0xA1)), "00000000000000A1")
    }

    func testSpotifyTrackIdThatIsNotTextIsUnknown() throws {
        let payload: [AnyHashable: Any] = ["Player State": "Playing", "Name": "Song", "Track ID": 42]
        XCTAssertNil(try XCTUnwrap(PlayerNotificationParser.parse(payload, from: .spotify)).info.trackID)
    }

    // Music's notification never carries a position, even if a payload has Spotify's key.
    func testMusicIgnoresAPlaybackPositionKey() throws {
        let payload: [AnyHashable: Any] = ["Player State": "Playing", "Name": "Song", "Playback Position": 30.0]
        XCTAssertNil(try XCTUnwrap(PlayerNotificationParser.parse(payload, from: .music)).info.position)
    }
}
