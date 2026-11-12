import CoreGraphics
import SwiftUI

/// Colours taken from the artwork for the full-screen player's clock and fallback background (D56).
enum ArtworkPalette {
    /// The artwork's average colour, as RGB in 0...1: the image drawn into one pixel. Pure, so tests feed it images.
    static func average(of image: CGImage) -> (red: Double, green: Double, blue: Double)? {
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (Double(pixel[0]) / 255, Double(pixel[1]) / 255, Double(pixel[2]) / 255)
    }

    /// The average lifted towards white, so the clock reads on the darkened, blurred artwork: a tint, not a colour.
    static func clockColour(for image: CGImage?) -> Color {
        guard let image, let average = average(of: image) else { return .white }
        func lift(_ value: Double) -> Double { value + (1 - value) * 0.7 }
        return Color(red: lift(average.red), green: lift(average.green), blue: lift(average.blue))
    }
}
