import SwiftUI

/// The full-screen player, v1 (D56): the artwork blurred across the screen, the date and time, the artwork, a compact
/// player under it and the lyrics under that. Sizes are shares of the screen's height, so it fits any display.
struct FullScreenPlayerView: View {
    let module: NowPlayingModule
    let close: () -> Void
    @AppStorage(LRCLibClient.enabledKey) private var lyricsOn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            ZStack {
                background
                    // A click on the background closes, like a click outside a sheet.
                    .contentShape(Rectangle())
                    .onTapGesture(perform: close)
                if let info = module.shown {
                    VStack(spacing: 0) {
                        clock(colour: ArtworkPalette.clockColour(for: info.artwork?.image), height: height)
                            .padding(.top, height * 0.06)
                        Spacer(minLength: height * 0.03)
                        NowPlayingArtworkView(artwork: info.artwork, player: info.player, size: height * 0.36)
                            .shadow(color: .black.opacity(0.45), radius: 30, y: 12)
                            .scaleEffect(appeared || reduceMotion ? 1 : 0.85)
                        FullScreenControlsView(module: module, info: info)
                            .padding(.top, height * 0.035)
                        lyrics(info)
                            .frame(maxWidth: min(proxy.size.width * 0.6, 720), minHeight: height * 0.16, alignment: .top)
                            .padding(.top, height * 0.03)
                        Spacer(minLength: height * 0.02)
                    }
                    .frame(maxWidth: .infinity)
                }
                closeButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(24)
            }
        }
        .environment(\.colorScheme, .dark)
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.easeOut(duration: reduceMotion ? 0.15 : 0.35)) { appeared = true } }
        .onExitCommand(perform: close)
        // The card's own lookup rule (D53): once per track, only while lyrics are on and this is on screen.
        .task(id: LyricsKey(trackID: module.shown?.trackID, on: lyricsOn)) { await module.loadLyrics() }
    }

    /// The artwork scaled past the edges and blurred, darkened so white text reads on it. Drawn once per track.
    @ViewBuilder
    private var background: some View {
        let artwork = module.shown?.artwork
        ZStack {
            Color.black
            if let artwork {
                Image(decorative: artwork.image, scale: 1)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(1.25)
                    .blur(radius: 60, opaque: true)
                    .id(artwork.trackID)
                    .transition(.opacity)
            }
            Color.black.opacity(0.3)
        }
        .animation(.easeInOut(duration: 0.6), value: artwork?.trackID)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func clock(colour: Color, height: CGFloat) -> some View {
        // One redraw a minute while it's open (ARCHITECTURE §9).
        TimelineView(.everyMinute) { context in
            VStack(spacing: 0) {
                Text(context.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .font(.system(size: height * 0.026, weight: .semibold))
                Text(context.date, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                    .font(.system(size: height * 0.115, weight: .bold, design: .rounded).monospacedDigit())
            }
            .foregroundStyle(colour)
            .shadow(color: .black.opacity(0.2), radius: 8)
        }
    }

    @ViewBuilder
    private func lyrics(_ info: NowPlayingInfo) -> some View {
        if !lyricsOn {
            Text("Turn on synced lyrics in Settings › Privacy to see them here.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.45))
        } else if let current = module.lyrics, current.trackID == info.trackID {
            LyricWordsView(lyrics: current.lyrics, info: info)
        } else {
            // Loading, or LRCLIB has none: nothing rather than a spinner that may never end.
            Color.clear
        }
    }

    private var closeButton: some View {
        Button(action: close) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.8))
        .help("Close (Esc)")
        .accessibilityLabel(Text("Close full-screen player"))
    }

    private struct LyricsKey: Equatable {
        var trackID: String?
        var on: Bool
    }
}

/// The compact player under the artwork (D56): title and artist with a waveform, the bar between the elapsed and
/// remaining time, and the controls with an output button.
struct FullScreenControlsView: View {
    let module: NowPlayingModule
    let info: NowPlayingInfo
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let width: CGFloat = 300

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        VStack(spacing: 8) {
            ZStack(alignment: .trailing) {
                VStack(spacing: 1) {
                    Text(verbatim: info.title ?? info.player.displayName)
                        .font(.system(size: 13, weight: .semibold))
                    if let artist = info.artist, info.title != nil {
                        Text(verbatim: artist).font(.system(size: 11)).foregroundStyle(.white.opacity(0.65))
                    }
                }
                .lineLimit(1)
                .padding(.horizontal, 28)
                .frame(maxWidth: .infinity)
                Image(systemName: "waveform")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .symbolEffect(.variableColor.iterative, isActive: info.isPlaying && !reduceMotion)
                    .accessibilityHidden(true)
            }
            if let duration = info.duration, duration > 0, info.position != nil {
                progress(duration: duration)
            }
            HStack(spacing: 30) {
                Color.clear.frame(width: 18, height: 1)
                control(.previous, "Previous track", "backward.fill")
                control(.playPause, module.isPlaying ? "Pause" : "Play", module.isPlaying ? "pause.fill" : "play.fill")
                    .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))
                control(.next, "Next track", "forward.fill")
                Button(action: openSoundOutput) {
                    Image(systemName: "headphones").font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 18)
                .help("Sound output")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: Self.width)
        .background(.ultraThinMaterial.opacity(0.9), in: shape)
        .overlay(shape.strokeBorder(.white.opacity(0.18)))
        .foregroundStyle(.white)
    }

    private func progress(duration: TimeInterval) -> some View {
        let now = Date()
        let elapsed = info.elapsed(at: now) ?? 0
        let start = now.addingTimeInterval(-elapsed)
        let pause = info.isPlaying ? nil : now
        return HStack(spacing: 8) {
            Text(timerInterval: start...start.addingTimeInterval(duration), pauseTime: pause, countsDown: false,
                 showsHours: false)
            GeometryReader { proxy in
                PlaybackProgressBar(elapsed: elapsed, duration: duration, isPlaying: info.isPlaying)
                    .frame(height: proxy.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        let fraction = min(max(location.x / max(proxy.size.width, 1), 0), 1)
                        Task { await module.perform(.seek(to: fraction * duration)) }
                    }
            }
            .frame(height: 14)
            Text(timerInterval: start...start.addingTimeInterval(duration), pauseTime: pause, countsDown: true,
                 showsHours: false)
        }
        .font(.system(size: 9, weight: .medium).monospacedDigit())
        .foregroundStyle(.white.opacity(0.6))
    }

    private func control(_ command: PlaybackCommand, _ label: LocalizedStringKey, _ systemImage: String) -> some View {
        Button {
            Task { await module.perform(command) }
        } label: {
            Label(label, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.system(size: command == .playPause ? 20 : 15))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func openSoundOutput() {
        // Undocumented URL [I], as the Automation link (D23); System Settings › Sound if it stops working.
        if let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension?output") { openURL(url) }
    }
}
