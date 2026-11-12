import SwiftUI

/// The compact lock-screen player (D58): a small glass card above the password prompt with the artwork, title and
/// artist, the bar and the controls. A click on the artwork, the title or the expand button opens the full screen.
struct CompactLockPlayerView: View {
    let module: NowPlayingModule
    let expand: () -> Void

    var body: some View {
        if let info = module.shown {
            // The lyrics button opens the full screen, where the lyrics are (Shash, 2026-11-13).
            FullScreenControlsView(module: module, info: info, leading: .lyrics(isOn: false, toggle: expand), artworkSize: 40,
                                   onHeaderTap: expand)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// The expanded lock-screen player, v1 (D56, D58): the artwork blurred and darkened across the screen, the date and
/// clock on top, the artwork on the left with the player under it, and the lyrics on the right. It covers the password
/// prompt, so the × top left collapses it; Touch ID and typing the password still work while it's up [I: device check].
struct FullScreenPlayerView: View {
    let module: NowPlayingModule
    let collapse: () -> Void
    @AppStorage(LRCLibClient.enabledKey) private var lyricsOn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The lyrics on the right; the lyrics button hides them and centres the artwork. Shown when it opens.
    @State private var showsLyrics = true

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height, width = proxy.size.width
            ZStack(alignment: .topLeading) {
                background
                if let info = module.shown {
                    clock(colour: ArtworkPalette.clockColour(for: info.artwork?.image), height: height)
                        .frame(maxWidth: .infinity)
                        .padding(.top, height * 0.07)
                    // Left: the artwork and the player, centred on the left third (from Shash's video, 2026-11-13).
                    VStack(spacing: height * 0.03) {
                        NowPlayingArtworkView(artwork: info.artwork, player: info.player, size: height * 0.34)
                            .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
                        FullScreenControlsView(module: module, info: info,
                                               leading: .lyrics(isOn: showsLyrics, toggle: { showsLyrics.toggle() }))
                    }
                    .frame(width: width * 0.40)
                    .position(x: width * (showsLyrics ? 0.31 : 0.5), y: height * 0.55)
                    // Right: the lyrics.
                    if showsLyrics {
                        lyrics(info)
                            .frame(width: width * 0.36, height: height * 0.6)
                            .position(x: width * 0.68, y: height * 0.56)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }
                collapseButton
                    .padding(24)
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.45, bounce: 0), value: showsLyrics)
        // Lyrics are looked up only while shown here, and then by D53's rules: once per track, with the setting on.
        .task(id: LyricsKey(trackID: module.shown?.trackID, on: lyricsOn && showsLyrics)) {
            if lyricsOn && showsLyrics { await module.loadLyrics() }
        }
    }

    /// The artwork, blurred once per track (`BlurredArtwork.cached`) and scaled past the edges, darkened so it reads as
    /// a tint, as in the video. A plain image: nothing is blurred while the view draws.
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
            Color.black.opacity(0.55)
        }
        .animation(.easeInOut(duration: 0.3), value: artwork?.trackID)
        .clipped()
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func clock(colour: Color, height: CGFloat) -> some View {
        // One redraw a minute while it's up (ARCHITECTURE §9).
        TimelineView(.everyMinute) { context in
            VStack(spacing: 0) {
                Text(context.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .font(.system(size: height * 0.022, weight: .semibold))
                Text(context.date, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                    .font(.system(size: height * 0.11, weight: .bold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .foregroundStyle(colour.opacity(0.8))
        }
    }

    @ViewBuilder
    private func lyrics(_ info: NowPlayingInfo) -> some View {
        Group {
            if !lyricsOn {
                Text("Turn on synced lyrics in Settings › Privacy to see them here.")
                    .foregroundStyle(.white.opacity(0.55))
            } else if let current = module.lyrics, current.trackID == info.trackID {
                LyricWordsView(lyrics: current.lyrics, info: info)
            } else {
                // Loading, or LRCLIB has none for this track.
                Text("No synced lyrics for this track.")
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .font(.title3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var collapseButton: some View {
        Button(action: collapse) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.8))
        .accessibilityLabel(Text("Back to the small player"))
    }

    private struct LyricsKey: Equatable {
        var trackID: String?
        var on: Bool
    }
}

/// The glass player card (D56, D58): artwork (compact only), title and artist with a waveform, the bar between the
/// elapsed and remaining time, and the controls with an optional expand button and an output button.
struct FullScreenControlsView: View {
    enum Leading {
        case none
        /// The lyrics button: filled while the lyrics show.
        case lyrics(isOn: Bool, toggle: () -> Void)
    }

    let module: NowPlayingModule
    let info: NowPlayingInfo
    var leading: Leading = .none
    /// Nil hides the artwork (the expanded view shows it large).
    var artworkSize: CGFloat?
    var onHeaderTap: (() -> Void)?
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let width: CGFloat = 300

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        VStack(spacing: 8) {
            header
            if let duration = info.duration, duration > 0, info.position != nil {
                progress(duration: duration)
            }
            HStack(spacing: 30) {
                leadingButton.frame(width: 18)
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

    private var header: some View {
        HStack(spacing: 10) {
            if let artworkSize {
                NowPlayingArtworkView(artwork: info.artwork, player: info.player, size: artworkSize)
            }
            VStack(alignment: artworkSize == nil ? .center : .leading, spacing: 1) {
                Text(verbatim: info.title ?? info.player.displayName)
                    .font(.system(size: 13, weight: .semibold))
                if let artist = info.artist, info.title != nil {
                    Text(verbatim: artist).font(.system(size: 11)).foregroundStyle(.white.opacity(0.65))
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: artworkSize == nil ? .center : .leading)
            Image(systemName: "waveform")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
                .symbolEffect(.variableColor.iterative, isActive: info.isPlaying && !reduceMotion)
                .accessibilityHidden(true)
        }
        .padding(.leading, artworkSize == nil ? 28 : 0)
        .contentShape(Rectangle())
        .onTapGesture { onHeaderTap?() }
    }

    @ViewBuilder
    private var leadingButton: some View {
        switch leading {
        case .none:
            Color.clear.frame(height: 1)
        case let .lyrics(isOn, toggle):
            Button(action: toggle) {
                Image(systemName: isOn ? "quote.bubble.fill" : "quote.bubble").font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(isOn ? 1 : 0.75))
            .help(isOn ? "Hide lyrics" : "Show lyrics")
            .accessibilityLabel(Text(isOn ? "Hide lyrics" : "Show lyrics"))
        }
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
