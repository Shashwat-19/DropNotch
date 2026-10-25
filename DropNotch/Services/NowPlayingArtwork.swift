import CoreGraphics
import Foundation
import ImageIO

/// A track's artwork as a small thumbnail, tied to the track it was fetched for (D25, D26).
struct NowPlayingArtwork: Equatable {
    let trackID: String
    let image: CGImage

    /// Longest side in pixels: the 56 pt artwork at 2×, with room to spare.
    static let maxPixelSize = 128

    /// Decodes `data` (from Music, or Spotify's image server) into a thumbnail; nil if it isn't an image.
    /// ImageIO scales while decoding, so the full-size image is never held. Can be slow: never call it
    /// on the main thread.
    init?(trackID: String, data: Data) {
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Self.maxPixelSize,
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        self.trackID = trackID
        self.image = image
    }

    // `CGImage` has no value equality; the same decoded image for the same track is the same artwork.
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.trackID == rhs.trackID && lhs.image === rhs.image }
}
