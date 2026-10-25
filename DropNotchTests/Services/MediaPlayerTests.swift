import XCTest
@testable import DropNotch

final class MediaPlayerTests: XCTestCase {
    func testFourCharCodePacksBigEndian() {
        XCTAssertEqual(FourCharCode(code: "hook"), 0x686F_6F6B)
        XCTAssertEqual(FourCharCode(code: "----"), 0x2D2D_2D2D)
    }

    // The codes the probe read from each app's `sdef` (D22).
    func testCommandEventsMatchTheScriptingDictionaries() {
        let expected: [(MediaPlayer, PlaybackCommand, String, String)] = [
            (.music, .playPause, "hook", "PlPs"), (.music, .next, "hook", "Next"), (.music, .previous, "hook", "Back"),
            (.spotify, .playPause, "spfy", "PlPs"), (.spotify, .next, "spfy", "Next"), (.spotify, .previous, "spfy", "Prev"),
        ]
        for (player, command, suite, id) in expected {
            let event = player.event(for: command)
            XCTAssertEqual(event.eventClass, FourCharCode(code: suite), "\(player) \(command)")
            XCTAssertEqual(event.eventID, FourCharCode(code: id), "\(player) \(command)")
        }
    }

    func testIdentifiersMatchTheProbe() {
        XCTAssertEqual(MediaPlayer.music.bundleID, "com.apple.Music")
        XCTAssertEqual(MediaPlayer.spotify.bundleID, "com.spotify.client")
        XCTAssertEqual(MediaPlayer.music.notificationName.rawValue, "com.apple.Music.playerInfo")
        XCTAssertEqual(MediaPlayer.spotify.notificationName.rawValue, "com.spotify.client.PlaybackStateChanged")
    }
}
