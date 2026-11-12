import SwiftUI

/// The lock-screen player (D55): the Home tab's Now Playing card (artwork, title, artist, lyric line if on, bar and
/// controls) on a dark rounded panel, so it reads on any wallpaper.
struct LockScreenPlayerView: View {
    let module: NowPlayingModule

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        module.expandedView()
            .padding(16)
            .frame(width: LockScreenPlayerWindow.size.width, height: LockScreenPlayerWindow.size.height)
            .background(shape.fill(.black.opacity(0.72)))
            .background(shape.fill(.ultraThinMaterial))
            .clipShape(shape)
            .environment(\.colorScheme, .dark)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Now Playing"))
    }
}
