import SwiftUI

/// The progress bar with the elapsed and total time (D26). Shown only when both are known.
struct PlaybackProgressView: View {
    let info: NowPlayingInfo
    let duration: TimeInterval
    /// Seek to these seconds (D26). Called on release, or per VoiceOver adjustment.
    let onSeek: (TimeInterval) -> Void
    /// While dragging: where the pointer is, as seconds. The bar follows it instead of the player.
    @State private var dragSeconds: TimeInterval?
    /// After a VoiceOver adjust: the position asked for. The seek lands later, so this is what VoiceOver
    /// speaks, and the next adjust's base, until the player's new position arrives.
    @State private var seekTarget: TimeInterval?
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverOn

    var body: some View {
        // The bar and the time text move on their own. Only for VoiceOver is the whole view redrawn, once a
        // second while playing, so the spoken position is current; otherwise this timeline is paused.
        TimelineView(.animation(minimumInterval: 1, paused: !(voiceOverOn && info.isPlaying))) { _ in
            // Not `context.date`: while paused it stays at the timeline's first entry, so after any update the
            // time text ran ahead by however long the view had been open [V: scratch probe, 2026-10-31].
            content(now: Date())
        }
        .onChange(of: info.position) { seekTarget = nil }
    }

    private func content(now: Date) -> some View {
        let elapsed = info.elapsed(at: now) ?? 0
        let start = now.addingTimeInterval(-elapsed)
        return HStack(spacing: 8) {
            // The gesture needs the bar's width to turn a pointer position into seconds.
            GeometryReader { geometry in
                PlaybackProgressBar(elapsed: dragSeconds ?? elapsed, duration: duration,
                                    isPlaying: dragSeconds == nil && info.isPlaying)
                    .contentShape(Rectangle())
                    .gesture(seekGesture(width: geometry.size.width))
            }
            // The bar is 4 pt; the 24 pt frame is the click and drag target (L7).
            .frame(height: 24)
            // SwiftUI updates this text about once a second while the view exists and is playing, visible or
            // not; closing the notch (including on screen sleep) removes it (ARCHITECTURE §9).
            (Text(timerInterval: start...start.addingTimeInterval(duration), pauseTime: info.isPlaying ? nil : now,
                  countsDown: false, showsHours: false)
                + Text(verbatim: " / " + Duration.seconds(duration).formatted(.time(pattern: .minuteSecond))))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Playback position"))
        .accessibilityValue(Text("\(Self.spoken(seekTarget ?? elapsed)) of \(Self.spoken(duration))"))
        // VoiceOver adjust only, 10 s a step. Arrow keys need focusable and onKeyPress once the panel can
        // take focus (L2, feat/hotkey).
        .accessibilityAdjustableAction { direction in
            // From now (or from an adjust still on its way), not from when the view was last drawn.
            let base = seekTarget ?? info.elapsed(at: Date()) ?? 0
            let target: TimeInterval
            switch direction {
            case .increment: target = min(duration, base + 10)
            case .decrement: target = max(0, base - 10)
            @unknown default: return
            }
            seekTarget = target
            onSeek(target)
        }
    }

    /// `minimumDistance: 0`, so a click seeks as well as a drag. The seek is sent once, on release.
    private func seekGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in dragSeconds = Self.seconds(at: value.location.x, width: width, duration: duration) }
            .onEnded { value in
                onSeek(Self.seconds(at: value.location.x, width: width, duration: duration))
                dragSeconds = nil
            }
    }

    /// Seconds for a point `x` along a bar `width` wide, clamped to the track. Internal for tests.
    static func seconds(at x: CGFloat, width: CGFloat, duration: TimeInterval) -> TimeInterval {
        guard width > 0 else { return 0 }
        return duration * Double(min(max(x / width, 0), 1))
    }

    private static func spoken(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds.rounded()).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
    }
}
