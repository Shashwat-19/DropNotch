import SwiftUI

/// Hover and press feedback for the Now Playing controls. From macOS 26 each control is a Liquid Glass
/// circle; before that, a white highlight circle. Only the controls change: the notch stays solid black (L5).
struct NowPlayingControlStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Control(configuration: configuration)
    }

    // A ButtonStyle can't hold @State, so the hover state lives in this view.
    private struct Control: View {
        let configuration: ButtonStyleConfiguration
        @State private var isHovered = false
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.colorSchemeContrast) private var contrast

        var body: some View {
            if #available(macOS 26.0, *) {
                // Interactive glass reacts to the pointer and to presses by itself [V: developer.apple.com,
                // "Applying Liquid Glass to custom views"].
                // shortcut: no GlassEffectContainer (Apple advises one for several glass views, for rendering cost)
                // because its spacing, which decides when shapes merge, isn't documented; add it if
                // performance-optimizer measures the three circles as costly.
                configuration.label.glassEffect(.regular.interactive(), in: .circle)
            } else {
                configuration.label
                    .background(Circle().fill(.white.opacity(highlight)))
                    .scaleEffect(configuration.isPressed && !reduceMotion ? 0.9 : 1)
                    .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                    .onHover { isHovered = $0 }
            }
        }

        private var highlight: Double {
            let strong = contrast == .increased
            if configuration.isPressed { return strong ? 0.35 : 0.25 }
            return isHovered ? (strong ? 0.2 : 0.12) : 0
        }
    }
}
