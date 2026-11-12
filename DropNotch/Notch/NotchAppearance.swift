import SwiftUI

/// Settings › General › Look (D52): the open notch in plain black, or in Liquid Glass on macOS 26 and later. The
/// closed and peeking notch stay black in both, since they have to read as part of the camera housing.
enum NotchAppearance: String, CaseIterable {
    case black, liquidGlass

    static let key = "notch.appearance"

    /// Whether this macOS has the Liquid Glass material. The deployment target stays 14.0 (D52).
    static var isGlassAvailable: Bool {
        if #available(macOS 26, *) { true } else { false }
    }

    /// Glass only where macOS has it, and never under Reduce Transparency, which asks for solid backgrounds.
    func usesGlass(reduceTransparency: Bool, glassAvailable: Bool = isGlassAvailable) -> Bool {
        self == .liquidGlass && glassAvailable && !reduceTransparency
    }
}

/// The notch's body: black, or tinted Liquid Glass while open (D52).
struct NotchBackground<S: Shape>: View {
    let shape: S
    let glass: Bool

    /// Dark enough that the white content keeps its contrast over a bright wallpaper. [I] Tune on device.
    static var tint: Color { .black.opacity(0.5) }

    var body: some View {
        if glass, #available(macOS 26, *) {
            Color.clear.glassEffect(.regular.tint(Self.tint), in: shape)
        } else {
            shape.fill(.black)
        }
    }
}
