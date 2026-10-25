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

    func testATallImageIsBoundByItsHeight() throws {
        let artwork = try XCTUnwrap(NowPlayingArtwork(trackID: "a", data: try png(width: 200, height: 1000)))
        XCTAssertEqual(artwork.image.height, NowPlayingArtwork.maxPixelSize)
        XCTAssertLessThan(artwork.image.width, NowPlayingArtwork.maxPixelSize)
    }

    // Spotify serves JPEG [V: media probe].
    func testDecodesJPEG() throws {
        let rep = try XCTUnwrap(NSBitmapImageRep(data: try png(width: 640, height: 640)))
        let jpeg = try XCTUnwrap(rep.representation(using: .jpeg, properties: [:]))
        let artwork = try XCTUnwrap(NowPlayingArtwork(trackID: "a", data: jpeg))
        XCTAssertEqual(artwork.image.width, NowPlayingArtwork.maxPixelSize)
    }

    // Music's cap is 10 MB (D26); a buffer that size with no image in it decodes to nothing.
    func testLargeDataThatIsNotAnImageGivesNothing() {
        XCTAssertNil(NowPlayingArtwork(trackID: "a", data: Data(count: 10 * 1024 * 1024 + 1)))
    }

    func testAPNGHeaderWithNoImageGivesNothing() throws {
        let header = try png(width: 64, height: 64).prefix(33) // signature and IHDR only
        XCTAssertNil(NowPlayingArtwork(trackID: "a", data: Data(header)))
    }

    // Equality is per decode: the same artwork compares equal, another track's never does.
    func testEqualityIsTheTrackAndTheDecodedImage() throws {
        let data = try png(width: 8, height: 8)
        let artwork = try XCTUnwrap(NowPlayingArtwork(trackID: "a", data: data))
        XCTAssertEqual(artwork, artwork)
        XCTAssertNotEqual(artwork, try XCTUnwrap(NowPlayingArtwork(trackID: "b", data: data)))
    }
}
