import SwiftUI

/// The full-screen player's lyrics (D56): the line before (dim), the current line lit word by word, and the line after
/// (dim). LRCLIB gives line timings only, so v1 spreads each line's words evenly over its time [I: close enough for
/// most songs; device check 147]. Redrawn at 15 fps while playing and on screen, nothing while paused.
struct LyricWordsView: View {
    let lyrics: SyncedLyrics
    let info: NowPlayingInfo
    /// Lines shown dimmed before and after the current one.
    var before = 1
    var after = 1
    var alignment: HorizontalAlignment = .center
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A line with nothing after it lights over this long.
    static let lastLineLength: TimeInterval = 4

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15, paused: !info.isPlaying)) { _ in
            let elapsed = info.elapsed(at: Date()) ?? 0
            let index = lyrics.lines.lastIndex { $0.time <= elapsed }
            let anchor = index ?? -1
            VStack(alignment: alignment, spacing: 14) {
                ForEach(Array((anchor - before)..<anchor), id: \.self) { line(at: $0) }
                current(index, elapsed: elapsed)
                ForEach(Array((anchor + 1)...(anchor + after)), id: \.self) { line(at: $0) }
            }
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: index)
        }
    }

    private var textAlignment: TextAlignment { alignment == .leading ? .leading : .center }

    private func line(at index: Int) -> some View {
        let text = lyrics.lines.indices.contains(index) ? lyrics.lines[index].text : ""
        return Text(verbatim: text.isEmpty ? " " : text)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white.opacity(0.35))
            .multilineTextAlignment(textAlignment)
            .lineLimit(2)
    }

    private func current(_ index: Int?, elapsed: TimeInterval) -> some View {
        let note = Text(verbatim: "♪").font(.system(size: 30, weight: .bold)).foregroundStyle(.white.opacity(0.6))
        guard let index else { return AnyView(note) }
        let line = lyrics.lines[index]
        let end = lyrics.lines.indices.contains(index + 1) ? lyrics.lines[index + 1].time : line.time + Self.lastLineLength
        let progress = Self.progress(elapsed: elapsed, start: line.time, end: end)
        let words = line.text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard !words.isEmpty else { return AnyView(note) }
        let lit = Self.litWords(count: words.count, progress: progress)
        // One Text built from runs, so the line wraps as words, not as separate views.
        let text = words.enumerated().reduce(Text(verbatim: "")) { result, item in
            let word = Text(verbatim: (item.offset == 0 ? "" : " ") + item.element)
                .foregroundStyle(item.offset < lit ? .white : .white.opacity(0.4))
            return result + word
        }
        return AnyView(text
            .font(.system(size: 30, weight: .bold))
            .multilineTextAlignment(textAlignment)
            .lineLimit(3)
            .accessibilityLabel(Text(verbatim: line.text)))
    }

    /// 0...1 through the line.
    static func progress(elapsed: TimeInterval, start: TimeInterval, end: TimeInterval) -> Double {
        guard end > start else { return 1 }
        return min(max((elapsed - start) / (end - start), 0), 1)
    }

    /// How many of `count` words are lit at `progress`: the first word lights as the line starts.
    static func litWords(count: Int, progress: Double) -> Int {
        min(count, Int((progress * Double(count)).rounded(.down)) + 1)
    }
}
