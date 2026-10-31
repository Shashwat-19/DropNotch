import SwiftUI

/// One side of the closed notch while music plays (D28): the artwork on the left, the bars on the right.
struct NowPlayingCompactView: View {
    let module: NowPlayingModule
    let slot: CompactSlot

    var body: some View {
        if let info = module.shown {
            switch slot {
            case .left:
                GeometryReader { proxy in
                    NowPlayingArtworkView(artwork: info.artwork, player: info.player,
                                          size: min(proxy.size.width, proxy.size.height))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .right:
                CompactWaveform(isPlaying: module.isPlaying)
                    // Decorative (D2): the open notch says what is playing.
                    .accessibilityHidden(true)
            }
        }
    }
}
