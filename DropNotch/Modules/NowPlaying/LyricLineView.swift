import SwiftUI

/// The lyric line playing now, in the Now Playing card (D53). Redrawn only at each line's start time, worked out from
/// the position anchor (D26), with `TimelineView(.explicit)`: no timer, no polling, and nothing while paused.
struct LyricLineView: View {
    let lyrics: SyncedLyrics
    let info: NowPlayingInfo
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A redraw at a line's start can land a hair early in floating point; looking this far ahead picks the new line.
    private static let lead: TimeInterval = 0.05

    var body: some View {
        let now = Date()
        let elapsed = info.elapsed(at: now) ?? 0
        let schedule = info.isPlaying ? lyrics.starts(after: elapsed).map { now.addingTimeInterval($0 - elapsed) } : []
        TimelineView(.explicit(schedule)) { context in
            let line = lyrics.line(at: (info.elapsed(at: context.date) ?? 0) + Self.lead)
            // Verbatim: lyrics are never looked up for translation. A gap or the intro shows a note.
            Text(verbatim: line.map { $0.text.isEmpty ? "♪" : $0.text } ?? "♪")
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .id(line?.time ?? -1)
                // A fade is what Reduce Motion asks for in place of motion (L8), so it stays on.
                .transition(.opacity)
                .animation(.easeInOut(duration: reduceMotion ? 0.1 : 0.2), value: line?.time)
        }
        .accessibilityLabel(Text("Lyrics"))
    }
}
