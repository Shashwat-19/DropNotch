import AppKit
import XCTest
@testable import DropNotch

final class NowPlayingArtworkTests: XCTestCase {
    private func png(width: Int, height: Int) throws -> Data {
        let rep = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        return try XCTUnwrap(rep.representation(using: .png, properties: [:]))
    }

    func testDecodesToAThumbnailKeepingTheShape() throws {
        let artwork = try XCTUnwrap(NowPlayingArtwork(trackID: "a", data: try png(width: 1024, height: 512)))
        XCTAssertEqual(artwork.image.width, NowPlayingArtwork.maxPixelSize)
        XCTAssertEqual(artwork.image.height, NowPlayingArtwork.maxPixelSize / 2)
        XCTAssertEqual(artwork.trackID, "a")
    }

    func testSmallImagesAreNotEnlarged() throws {
        let artwork = try XCTUnwrap(NowPlayingArtwork(trackID: "a", data: try png(width: 40, height: 40)))
        XCTAssertLessThanOrEqual(artwork.image.width, 40)
    }

    func testDataThatIsNotAnImageGivesNothing() {
        XCTAssertNil(NowPlayingArtwork(trackID: "a", data: Data("<html>not an image</html>".utf8)))
        XCTAssertNil(NowPlayingArtwork(trackID: "a", data: Data()))
        XCTAssertNil(NowPlayingArtwork(trackID: "a", data: Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00])))
    }
}
