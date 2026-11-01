import SwiftUI

/// Now Playing in the open notch: artwork, title, artist, the progress bar and three controls (D22–D26).
struct NowPlayingExpandedView: View {
    let module: NowPlayingModule
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The title and artist on screen. A change fades this out, then swaps it, then fades in (D27); nil until
    /// the first appearance shows the current ones.
    @State private var displayedText: TrackText?
    @State private var textOpacity = 1.0
    /// Keyboard focus. Only the hotkey makes the panel key, so this stays nil while hovering (D30).
    @FocusState private var focus: Focus?
    @Environment(\.notchHasKeyboardFocus) private var hasKeyboardFocus

    var body: some View {
        if let info = module.shown {
            let text = displayedText ?? TrackText(info)
            VStack(spacing: NotchStyle.spacing) {
                HStack(spacing: 12) {
                    NowPlayingArtworkView(artwork: info.artwork, player: info.player, size: 56)
                    VStack(alignment: .leading, spacing: NotchStyle.tightSpacing) {
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
                            .keyboardControl(Focus.settingsLink, focus: $focus, action: openAutomationSettings)
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
            // Set explicitly: the panel turns key in the same turn as the open, before SwiftUI inserts this view,
            // and a hover-opened notch already has it, so `.defaultFocus` alone doesn't land (code-reviewer W1).
            .onChange(of: hasKeyboardFocus, initial: true) { if hasKeyboardFocus { focus = .playPause } }
            .onMoveCommand { moveFocus($0, denied: module.deniedPlayer == info.player) }
            .lineLimit(1)
            // The open content is inserted each time the notch opens (D19), so this runs once per open.
            .onAppear {
                displayedText = TrackText(info)
                module.didOpen()
            }
            .onChange(of: TrackText(info)) { fadeToCurrentText() }
        } else {
            NotchEmptyState("Nothing playing in Music or Spotify", systemImage: "music.note")
        }
    }

    private func controls(isPlaying: Bool) -> some View {
        HStack(spacing: 24) {
            control(.previous, "Previous track", systemImage: "backward.fill")
            control(.playPause, isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                // Play morphs into pause; under Reduce Motion it only fades.
                .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))
                .animation(NotchStyle.spring, value: isPlaying)
            control(.next, "Next track", systemImage: "forward.fill")
        }
        // Not disabled while a command is in flight: that dimmed the controls on every click. `perform`
        // still drops clicks until the reply (and the Automation prompt) is back (D23).
    }

    private func control(_ command: PlaybackCommand, _ label: LocalizedStringKey, systemImage: String) -> some View {
        // `_ =` discards the Task, so the closure is the `() -> Void` that Button and `onKeyPress` take.
        let action = { _ = Task { await module.perform(command) } }
        return Button(action: action) {
            // Icon-only on screen; VoiceOver reads the label.
            Label(label, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.title3)
                // At least the ~24 pt target L7 asks for; the whole highlight circle is clickable.
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .buttonStyle(NowPlayingControlStyle())
        .keyboardControl(Focus(command), focus: $focus, action: action)
        // The style's circle shows focus; the system's rectangular ring would sit around it as well.
        .focusEffectDisabled()
    }

    /// Arrows step through the controls in reading order and stop at either end (D30).
    private func moveFocus(_ direction: MoveCommandDirection, denied: Bool) {
        let order = (denied ? [Focus.settingsLink] : []) + [.previous, .playPause, .next]
        guard let current = focus, let index = order.firstIndex(of: current) else {
            focus = .playPause
            return
        }
        switch direction {
        case .left, .up: focus = order[max(index - 1, 0)]
        case .right, .down: focus = order[min(index + 1, order.count - 1)]
        @unknown default: break
        }
    }

    /// The old text fades out, then the current one fades in, 0.12 s each, so the two never overlap. A fade is
    /// what Reduce Motion substitutes for motion (L8), so it stays on.
    /// `displayedText` only changes once the old text is invisible, so the new title never shows for a frame
    /// before the fade.
    private func fadeToCurrentText() {
        withAnimation(.easeOut(duration: 0.12)) {
            textOpacity = 0
        } completion: {
            // Whatever is current by now, so a second change during the fade isn't lost.
            displayedText = module.shown.map(TrackText.init)
            withAnimation(.easeIn(duration: 0.12)) { textOpacity = 1 }
        }
    }

    private func openAutomationSettings() {
        // Undocumented URL [I] (D23). If it stops working, the button's text still says where to go.
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            openURL(url)
        }
    }

    private enum Focus: Hashable {
        case settingsLink, previous, playPause, next

        init(_ command: PlaybackCommand) {
            switch command {
            case .previous: self = .previous
            case .next: self = .next
            case .playPause, .seek: self = .playPause
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
}

