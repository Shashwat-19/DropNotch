import SwiftUI

/// Now Playing in the open notch: artwork, title, artist, the progress bar and three controls (D22–D26).
struct NowPlayingExpandedView: View {
    let module: NowPlayingModule
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The old track's title and artist while they fade out; nil shows the current ones (D27).
    @State private var fadingText: TrackText?
    @State private var textOpacity = 1.0

    var body: some View {
        if let info = module.shown {
            let text = fadingText ?? TrackText(info)
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    NowPlayingArtworkView(artwork: info.artwork, player: info.player, size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        // Verbatim (a String, not a literal): track names are never looked up for translation.
                        Text(text.title)
                            .font(.subheadline.weight(.semibold))
                            .opacity(textOpacity)
                        if module.deniedPlayer == info.player {
                            Button(action: openAutomationSettings) {
                                // Underlined as well as coloured, so it reads as a link without colour (L6).
                                Text("Allow control of \(info.player.displayName) in System Settings").underline()
                                    // A 24 pt target (L7): it is the only way out of the denied state.
                                    .frame(minHeight: 24, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.link)
                            .font(.subheadline)
                        } else if let artist = text.artist {
                            Text(artist)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .opacity(textOpacity)
                        }
                        // An ad can report a zero duration: no bar rather than a dead one.
                        if let duration = info.duration, duration > 0, info.position != nil {
                            PlaybackProgressView(info: info, duration: duration) { seconds in
                                Task { await module.perform(.seek(to: seconds)) }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                controls(isPlaying: module.isPlaying)
            }
            .lineLimit(1)
            .padding(.horizontal, 24)
            // One group named after the module, so VoiceOver announces where the controls belong (L4).
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(module.title))
            // The open content is inserted each time the notch opens (D19), so this runs once per open.
            .onAppear { module.didOpen() }
            .onChange(of: TrackText(info)) { old, _ in fade(from: old) }
        } else {
            Text("Nothing playing")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func controls(isPlaying: Bool) -> some View {
        HStack(spacing: 24) {
            control(.previous, "Previous track", systemImage: "backward.fill")
            control(.playPause, isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                // Play morphs into pause; under Reduce Motion it only fades.
                .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))
                .animation(.default, value: isPlaying)
            control(.next, "Next track", systemImage: "forward.fill")
        }
        // Not disabled while a command is in flight: that dimmed the controls on every click. `perform`
        // still drops clicks until the reply (and the Automation prompt) is back (D23).
    }

    private func control(_ command: PlaybackCommand, _ label: LocalizedStringKey, systemImage: String) -> some View {
        Button {
            Task { await module.perform(command) }
        } label: {
            // Icon-only on screen; VoiceOver reads the label.
            Label(label, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.title3)
                // At least the ~24 pt target L7 asks for; the whole highlight circle is clickable.
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .buttonStyle(NowPlayingControlStyle())
    }

    /// The old text fades out, then the current one fades in, 0.12 s each, so the two never overlap. A fade is
    /// what Reduce Motion substitutes for motion (L8), so it stays on.
    private func fade(from old: TrackText) {
        if fadingText == nil { fadingText = old }
        withAnimation(.easeOut(duration: 0.12)) {
            textOpacity = 0
        } completion: {
            // Whatever is current by now, so a second change during the fade isn't lost.
            fadingText = nil
            withAnimation(.easeIn(duration: 0.12)) { textOpacity = 1 }
        }
    }

    private func openAutomationSettings() {
        // Undocumented URL [I] (D23). If it stops working, the button's text still says where to go.
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            openURL(url)
        }
    }
}

/// The title and artist lines, compared to tell when a new track's text should fade in.
private struct TrackText: Equatable {
    var title: String
    var artist: String?

    init(_ info: NowPlayingInfo) {
        title = info.title ?? info.player.displayName
        artist = info.title == nil ? nil : info.artist
    }
}
