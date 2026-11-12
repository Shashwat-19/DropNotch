import CoreGraphics
import Foundation
import ImageIO

/// A track's artwork as a small thumbnail, tied to the track it was fetched for (D25, D26).
struct NowPlayingArtwork: Equatable {
    let trackID: String
    let image: CGImage

    /// Longest side in pixels: the full-screen player's artwork, about 340 pt, at about 2× (D56). Was 128 for the
    /// 56 pt card artwork alone; a 640 px thumbnail is 1.6 MB in memory, one per track.
    static let maxPixelSize = 640
    /// ImageIO recognises formats from the bytes, whatever the label said. Only these two are decoded:
    /// artwork is JPEG or PNG [V: both probes], and other decoders are attack surface (security-auditor M1).
    static let formats: Set<String> = ["public.jpeg", "public.png"]
    /// Larger images are refused from their header, before decoding: a 16000 px PNG under 1 MB took
    /// over a second to scale down (security-auditor L5).
    static let maxSourcePixels = 8192

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
              let format = CGImageSourceGetType(source) as String?, Self.formats.contains(format),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              max(width, height) <= Self.maxSourcePixels,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        self.trackID = trackID
        self.image = image
    }

    // `CGImage` has no value equality; the same decoded image for the same track is the same artwork.
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.trackID == rhs.trackID && lhs.image === rhs.image }
}
