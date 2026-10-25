import SwiftUI

/// The progress bar with the elapsed and total time (D26). Shown only when both are known.
struct PlaybackProgressView: View {
    let info: NowPlayingInfo
    let duration: TimeInterval

    var body: some View {
        let now = Date()
        let elapsed = info.elapsed(at: now) ?? 0
        let start = now.addingTimeInterval(-elapsed)
        HStack(spacing: 8) {
            PlaybackProgressBar(elapsed: elapsed, duration: duration, isPlaying: info.isPlaying)
                .frame(height: 12)
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
    }

    private static func spoken(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds.rounded()).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
    }
}
