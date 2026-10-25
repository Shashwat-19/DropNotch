import XCTest
@testable import DropNotch

final class PlaybackProgressViewTests: XCTestCase {
    func testTheEndsOfTheBarAreTheEndsOfTheTrack() {
        XCTAssertEqual(PlaybackProgressView.seconds(at: 0, width: 200, duration: 180), 0)
        XCTAssertEqual(PlaybackProgressView.seconds(at: 200, width: 200, duration: 180), 180)
    }

    func testANegativeWidthSeeksToTheStart() {
        XCTAssertEqual(PlaybackProgressView.seconds(at: 10, width: -50, duration: 180), 0)
    }

    func testAZeroDurationTrackAlwaysSeeksToZero() {
        XCTAssertEqual(PlaybackProgressView.seconds(at: 120, width: 200, duration: 0), 0)
    }

    // A sub-point bar (mid-layout) still gives an in-range value.
    func testATinyWidthStaysInRange() {
        XCTAssertEqual(PlaybackProgressView.seconds(at: 5, width: 0.5, duration: 180), 180)
        XCTAssertEqual(PlaybackProgressView.seconds(at: 0.25, width: 0.5, duration: 180), 90)
    }
}
