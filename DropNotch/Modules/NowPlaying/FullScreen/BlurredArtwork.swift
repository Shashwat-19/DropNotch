import CoreGraphics
import CoreImage

/// The full-screen player's background (D56), blurred once per track instead of by SwiftUI on every frame: the
/// artwork shrunk to 96 px, blurred, and drawn scaled up, which looks the same as a large live blur and costs one
/// small Core Image pass. A live 60 pt blur over the whole screen made the player stutter (Shash, 2026-11-13).
enum BlurredArtwork {
    /// Longest side of the blurred image, in pixels.
    static let side: CGFloat = 96
    private static let context = CIContext(options: [.cacheIntermediates: false])
    /// The last few tracks' backgrounds, so opening the player or going back a track shows one in the first frame.
    @MainActor private static var cache: [(trackID: String, image: CGImage)] = []

    /// The background for `artwork`, made on the spot the first time (a few milliseconds) and kept for the next 4
    /// tracks. Synchronous on purpose: made after the window appeared, the background arrived late (Shash, 2026-11-13).
    @MainActor
    static func cached(for artwork: NowPlayingArtwork) -> CGImage? {
        if let hit = cache.first(where: { $0.trackID == artwork.trackID }) { return hit.image }
        guard let image = make(from: artwork.image) else { return nil }
        cache.insert((artwork.trackID, image), at: 0)
        if cache.count > 4 { cache.removeLast() }
        return image
    }

    /// Slow-ish (a few milliseconds): call it off the main actor.
    nonisolated static func make(from image: CGImage) -> CGImage? {
        let input = CIImage(cgImage: image)
        let longest = max(input.extent.width, input.extent.height)
        guard longest > 0 else { return nil }
        let scale = side / longest
        let small = input.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        // Clamped first, so the edges don't fade to transparent; cropped back to the small image after.
        let blurred = small.clampedToExtent().applyingGaussianBlur(sigma: 6).cropped(to: small.extent)
        return context.createCGImage(blurred, from: blurred.extent)
    }
}
