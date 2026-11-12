import CoreGraphics
import XCTest
@testable import DropNotch

final class FullScreenPlayerTests: XCTestCase {
    func testWordsLightInOrderAcrossTheLine() {
        XCTAssertEqual(LyricWordsView.progress(elapsed: 10, start: 10, end: 14), 0)
        XCTAssertEqual(LyricWordsView.progress(elapsed: 12, start: 10, end: 14), 0.5)
        XCTAssertEqual(LyricWordsView.progress(elapsed: 20, start: 10, end: 14), 1)
        XCTAssertEqual(LyricWordsView.progress(elapsed: 5, start: 10, end: 14), 0)
        XCTAssertEqual(LyricWordsView.progress(elapsed: 10, start: 10, end: 10), 1, "a zero-length line is lit")
        XCTAssertEqual(LyricWordsView.litWords(count: 4, progress: 0), 1, "the first word lights as the line starts")
        XCTAssertEqual(LyricWordsView.litWords(count: 4, progress: 0.5), 3)
        XCTAssertEqual(LyricWordsView.litWords(count: 4, progress: 1), 4)
    }

    func testClockTakesALightTintOfTheArtwork() throws {
        // A solid dark red image.
        let context = try XCTUnwrap(CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 32,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(red: 0.5, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        let image = try XCTUnwrap(context.makeImage())
        let average = try XCTUnwrap(ArtworkPalette.average(of: image))
        XCTAssertEqual(average.red, 0.5, accuracy: 0.02)
        XCTAssertEqual(average.green, 0, accuracy: 0.02)
        XCTAssertEqual(average.blue, 0, accuracy: 0.02)
    }

    @MainActor
    func testOpensOnlyWithATrackLoaded() {
        let module = NowPlayingModule(source: NoNowPlayingSource())
        let player = FullScreenPlayer(module: module)
        player.open()
        XCTAssertFalse(player.isOpen, "nothing playing: nothing to show")
    }
}

final class BlurredArtworkTests: XCTestCase {
    func testBlurIsSmallAndKeepsTheShape() throws {
        let context = try XCTUnwrap(CGContext(data: nil, width: 640, height: 320, bitsPerComponent: 8, bytesPerRow: 0,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 640, height: 320))
        let blurred = try XCTUnwrap(BlurredArtwork.make(from: try XCTUnwrap(context.makeImage())))
        XCTAssertEqual(blurred.width, 96)
        XCTAssertEqual(blurred.height, 48)
    }
}
