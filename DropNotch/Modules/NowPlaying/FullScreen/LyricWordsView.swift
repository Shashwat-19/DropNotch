import SwiftUI

/// The expanded lock-screen player's lyrics (D56, D58): every line in a column that glides to keep the current line at
/// the same height, with the lines around it dimmed, and the current line filling word by word. LRCLIB gives line
/// timings only, so a line's words fill evenly across its time [I: close enough for most songs; device check].
/// Redraws: the column once per line start (`TimelineView(.explicit)`), the current line at 30 fps while playing.
struct LyricWordsView: View {
    let lyrics: SyncedLyrics
    let info: NowPlayingInfo

    /// A redraw at a line's start can land a hair early in floating point; looking this far ahead picks the new line.
    static let lead: TimeInterval = 0.05
    /// A line with nothing after it fills over this long.
    static let lastLineLength: TimeInterval = 4

    var body: some View {
        let now = Date()
        let elapsed = info.elapsed(at: now) ?? 0
        let schedule = info.isPlaying ? lyrics.starts(after: elapsed).map { now.addingTimeInterval($0 - elapsed) } : []
        TimelineView(.explicit(schedule)) { context in
            let index = lyrics.lines.lastIndex { $0.time <= (info.elapsed(at: context.date) ?? 0) + Self.lead }
            LyricColumn(lyrics: lyrics, info: info, index: index)
        }
    }

    /// 0...1 through the line.
    static func progress(elapsed: TimeInterval, start: TimeInterval, end: TimeInterval) -> Double {
        guard end > start else { return 1 }
        return min(max((elapsed - start) / (end - start), 0), 1)
    }

    /// How lit each of `count` words is at `progress`, 0...1: words fill one after another, each over its share of the
    /// line, so the fill moves smoothly instead of jumping a word at a time.
    static func wordFill(count: Int, progress: Double) -> [Double] {
        (0..<count).map { min(max(progress * Double(count) - Double($0), 0), 1) }
    }
}

/// All the lines, moved so the current one sits a third of the way down. Each line's height is measured once and the
/// column is moved by an offset: no scroll view, since scrolling inside the lock-screen window crashed it in a layout
/// loop (2026-11-13).
private struct LyricColumn: View {
    let lyrics: SyncedLyrics
    let info: NowPlayingInfo
    let index: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Measured heights by line; a line not measured yet counts as one line of text.
    @State private var heights: [Int: CGFloat] = [:]

    static let spacing: CGFloat = 22
    /// The current line's top, as a share of the column's height.
    static let anchor: CGFloat = 0.34

    var body: some View {
        GeometryReader { proxy in
            let current = index ?? 0
            let above = (0..<current).reduce(CGFloat(0)) { $0 + (heights[$1] ?? 32) + Self.spacing }
            VStack(alignment: .leading, spacing: Self.spacing) {
                ForEach(lyrics.lines.indices, id: \.self) { line in
                    row(line)
                        .background(GeometryReader { row in
                            Color.clear.preference(key: LyricRowHeights.self, value: [line: row.size.height])
                        })
                }
            }
            .frame(width: proxy.size.width, alignment: .leading)
            .offset(y: proxy.size.height * Self.anchor - above)
            .animation(reduceMotion ? nil : .spring(duration: 0.7, bounce: 0.12), value: index)
        }
        .clipped()
        .onPreferenceChange(LyricRowHeights.self) { heights = $0 }
        // The column fades out at the top and bottom instead of ending in a hard line.
        .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.15),
                                     .init(color: .black, location: 0.8), .init(color: .clear, location: 1)],
                             startPoint: .top, endPoint: .bottom))
    }

    @ViewBuilder
    private func row(_ line: Int) -> some View {
        let distance = abs(line - (index ?? -1))
        Group {
            if line == index {
                CurrentLyricLine(lyrics: lyrics, info: info, index: line)
            } else {
                Text(verbatim: text(line))
                    .foregroundStyle(.white.opacity(distance == 1 ? 0.4 : 0.22))
            }
        }
        .font(.system(size: 26, weight: .bold))
        .multilineTextAlignment(.leading)
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)
        // The current line a touch larger; drawn larger only, so the measured heights don't change.
        .scaleEffect(line == index ? 1 : 0.94, anchor: .leading)
    }

    private func text(_ line: Int) -> String {
        let text = lyrics.lines[line].text
        return text.isEmpty ? "♪" : text
    }
}

/// Each lyric line's height, by index.
private struct LyricRowHeights: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

/// The line being sung, filling word by word at 30 fps while playing; still while paused.
private struct CurrentLyricLine: View {
    let lyrics: SyncedLyrics
    let info: NowPlayingInfo
    let index: Int

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !info.isPlaying)) { _ in
            let line = lyrics.lines[index]
            let end = lyrics.lines.indices.contains(index + 1) ? lyrics.lines[index + 1].time
                : line.time + LyricWordsView.lastLineLength
            let progress = LyricWordsView.progress(elapsed: info.elapsed(at: Date()) ?? 0, start: line.time, end: end)
            let words = line.text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            if words.isEmpty {
                Text(verbatim: "♪").foregroundStyle(.white.opacity(0.4 + 0.6 * progress))
            } else {
                let fill = LyricWordsView.wordFill(count: words.count, progress: progress)
                // One Text from runs, so the line wraps as words, not as separate views.
                words.enumerated().reduce(Text(verbatim: "")) { result, item in
                    result + Text(verbatim: (item.offset == 0 ? "" : " ") + item.element)
                        .foregroundStyle(.white.opacity(0.4 + 0.6 * fill[item.offset]))
                }
                .accessibilityLabel(Text(verbatim: line.text))
            }
        }
    }
}
