import SwiftUI

/// The progress bar with the elapsed and total time (D26). Shown only when both are known.
struct PlaybackProgressView: View {
    let info: NowPlayingInfo
    let duration: TimeInterval
    /// Seek to these seconds (D26). Called on release, or per VoiceOver adjustment.
    let onSeek: (TimeInterval) -> Void
    /// While dragging: where the pointer is, as seconds. The bar follows it instead of the player.
    @State private var dragSeconds: TimeInterval?

    var body: some View {
        let now = Date()
        let elapsed = info.elapsed(at: now) ?? 0
        let start = now.addingTimeInterval(-elapsed)
        HStack(spacing: 8) {
            // The gesture needs the bar's width to turn a pointer position into seconds.
            GeometryReader { geometry in
                PlaybackProgressBar(elapsed: dragSeconds ?? elapsed, duration: duration,
                                    isPlaying: dragSeconds == nil && info.isPlaying)
                    .contentShape(Rectangle())
                    .gesture(seekGesture(width: geometry.size.width))
            }
            // The bar is 4 pt; the 24 pt frame is the click and drag target (L7).
            .frame(height: 24)
            // SwiftUI updates this text itself, once a second, only while it is on screen and playing.
            (Text(timerInterval: start...start.addingTimeInterval(duration), pauseTime: info.isPlaying ? nil : now,
                  countsDown: false, showsHours: false)
                + Text(verbatim: " / " + Duration.seconds(duration).formatted(.time(pattern: .minuteSecond))))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Playback position"))
        .accessibilityValue(Text("\(Self.spoken(elapsed)) of \(Self.spoken(duration))"))
        // VoiceOver's adjust gesture (and arrow keys, once the panel can take focus: L2) moves 10 s.
        .accessibilityAdjustableAction { direction in
            // Now, not when the view was last drawn: it isn't redrawn while the track plays on.
            let elapsed = info.elapsed(at: Date()) ?? 0
            switch direction {
            case .increment: onSeek(min(duration, elapsed + 10))
            case .decrement: onSeek(max(0, elapsed - 10))
            @unknown default: break
            }
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
