import AppKit
import SwiftUI

/// The track's artwork, or the player's app icon when there is none (D26). Shared with the compact slot,
/// which shows it at a smaller size.
struct NowPlayingArtworkView: View {
    let artwork: NowPlayingArtwork?
    let player: MediaPlayer
    let size: CGFloat

    var body: some View {
        ZStack {
            Group {
                if let artwork {
                    Image(decorative: artwork.image, scale: 1).resizable().scaledToFill()
                } else {
                    Image(nsImage: PlayerIcons.icon(for: player)).resizable()
                }
            }
            // A new identity per picture, so a new one fades in over the old one (~0.2 s).
            .id(pictureID)
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.2), value: pictureID)
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.15))
        // Decorative: the title next to it already says what is playing.
        .accessibilityHidden(true)
    }

    private var pictureID: String { artwork?.trackID ?? player.bundleID }
}

/// App icons looked up once per player: `NSWorkspace` reads them from disk.
@MainActor
private enum PlayerIcons {
    static var cache: [MediaPlayer: NSImage] = [:]

    static func icon(for player: MediaPlayer) -> NSImage {
        if let icon = cache[player] { return icon }
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: player.bundleID)
        let icon = url.map { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSImage(systemSymbolName: "music.note", accessibilityDescription: nil) ?? NSImage()
        cache[player] = icon
        return icon
    }
}
