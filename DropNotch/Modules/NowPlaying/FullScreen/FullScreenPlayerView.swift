import SwiftUI

/// The full-screen player, v1 (D56): the artwork blurred across the screen, the date and time, the artwork, a compact
/// player under it and the lyrics under that. Sizes are shares of the screen's height, so it fits any display.
struct FullScreenPlayerView: View {
    let module: NowPlayingModule
    let close: () -> Void
    @AppStorage(LRCLibClient.enabledKey) private var lyricsOn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The lyrics panel on the right, opened with the player's lyrics button (Shash, 2026-11-13). Closed at first.
    @State private var showsLyrics = false

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height, width = proxy.size.width
            ZStack {
                background
                    // A click on the background closes, like a click outside a sheet.
                    .contentShape(Rectangle())
                    .onTapGesture(perform: close)
                if let info = module.shown {
                    VStack(spacing: 0) {
                        clock(colour: ArtworkPalette.clockColour(for: info.artwork?.image), height: height)
                            .frame(height: height * 0.21, alignment: .bottom)
                            .padding(.top, height * 0.04)
                        // The artwork and player in the middle; with lyrics open, on the left with the lyrics on the right.
                        HStack(alignment: .center, spacing: 0) {
                            VStack(spacing: 0) {
                                NowPlayingArtworkView(artwork: info.artwork, player: info.player, size: height * 0.36)
                                    .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
                                FullScreenControlsView(module: module, info: info, showsLyrics: $showsLyrics)
                                    .padding(.top, height * 0.035)
                            }
                            .frame(maxWidth: .infinity)
                            if showsLyrics {
                                lyricsPanel(info)
                                    .frame(width: width * 0.42, height: height * 0.55)
                                    .padding(.trailing, width * 0.06)
                                    .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                        }
                        .padding(.top, height * 0.05)
                        Spacer(minLength: 0)
                    }
                    .animation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0), value: showsLyrics)
                }
                closeButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(24)
            }
        }
        .environment(\.colorScheme, .dark)
        .onExitCommand(perform: close)
        // Lyrics are looked up only with the panel open, and then by D53's rules: once per track, setting on.
        .task(id: LyricsKey(trackID: module.shown?.trackID, on: lyricsOn && showsLyrics)) {
            if lyricsOn && showsLyrics { await module.loadLyrics() }
        }
    }

    /// The artwork, blurred once per track (`BlurredArtwork.cached`) and scaled past the edges, darkened so white text
    /// reads on it. A plain image: nothing is blurred while the view draws.
    @ViewBuilder
    private var background: some View {
        let artwork = module.shown?.artwork
        ZStack {
            Color.black
            if let artwork, let blurred = BlurredArtwork.cached(for: artwork) {
                Image(decorative: blurred, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .scaleEffect(1.1)
                    .id(artwork.trackID)
                    .transition(.opacity)
            }
            Color.black.opacity(0.3)
        }
        .animation(.easeInOut(duration: 0.3), value: artwork?.trackID)
        .clipped()
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func clock(colour: Color, height: CGFloat) -> some View {
        // One redraw a minute while it's open (ARCHITECTURE §9).
        TimelineView(.everyMinute) { context in
            VStack(spacing: 0) {
                Text(context.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .font(.system(size: height * 0.024, weight: .semibold))
                Text(context.date, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                    .font(.system(size: height * 0.12, weight: .bold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .foregroundStyle(colour)
            .shadow(color: .black.opacity(0.2), radius: 8)
        }
    }

    @ViewBuilder
    private func lyricsPanel(_ info: NowPlayingInfo) -> some View {
        Group {
            if !lyricsOn {
                Text("Turn on synced lyrics in Settings › Privacy to see them here.")
                    .foregroundStyle(.white.opacity(0.55))
            } else if let current = module.lyrics, current.trackID == info.trackID {
                LyricWordsView(lyrics: current.lyrics, info: info, before: 2, after: 4, alignment: .leading)
            } else {
                // Loading, or LRCLIB has none for this track.
                Text("No synced lyrics for this track.")
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .font(.title3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
    @Binding var showsLyrics: Bool
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
                Button { showsLyrics.toggle() } label: {
                    Image(systemName: showsLyrics ? "quote.bubble.fill" : "quote.bubble").font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(showsLyrics ? 1 : 0.6))
                .frame(width: 18)
                .help(showsLyrics ? "Hide lyrics" : "Show lyrics")
                .accessibilityLabel(Text(showsLyrics ? "Hide lyrics" : "Show lyrics"))
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
