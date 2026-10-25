import SwiftUI

/// Now Playing in the open notch: title, artist and three controls (D22–D24).
struct NowPlayingExpandedView: View {
    let module: NowPlayingModule
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let info = module.info {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    NowPlayingArtworkView(artwork: info.artwork, player: info.player, size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        // Verbatim (a String, not a literal): track names are never looked up for translation.
                        Text(info.title ?? info.player.displayName)
                            .font(.subheadline.weight(.semibold))
                        if module.deniedPlayer == info.player {
                            Button(action: openAutomationSettings) {
                                // Underlined as well as coloured, so it reads as a link without colour (L6).
                                Text("Allow control of \(info.player.displayName) in System Settings").underline()
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.link)
                            .font(.subheadline)
                        } else if info.title != nil, let artist = info.artist {
                            Text(artist)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let duration = info.duration, info.position != nil {
                            PlaybackProgressView(info: info, duration: duration) { seconds in
                                Task { await module.perform(.seek(to: seconds)) }
                            }
                            .disabled(module.isSending)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                controls(isPlaying: info.isPlaying)
            }
            .lineLimit(1)
            .padding(.horizontal, 24)
            // One group named after the module, so VoiceOver announces where the controls belong (L4).
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(module.title))
            // The open content is inserted each time the notch opens (D19), so this runs once per open.
            .onAppear { module.didOpen() }
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
            control(.next, "Next track", systemImage: "forward.fill")
        }
        // Also covers the wait for the Automation prompt, so clicks don't queue up behind it (D23).
        .disabled(module.isSending)
    }

    private func control(_ command: PlaybackCommand, _ label: LocalizedStringKey, systemImage: String) -> some View {
        Button {
            Task { await module.perform(command) }
        } label: {
            // Icon-only on screen; VoiceOver reads the label.
            Label(label, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.title3)
                // At least the ~24 pt target L7 asks for, with the whole square clickable.
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func openAutomationSettings() {
        // Undocumented URL [I] (D23). If it stops working, the button's text still says where to go.
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            openURL(url)
        }
    }
}
