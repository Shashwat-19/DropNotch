import Foundation

/// Time-synced lyrics from an LRC text (D53): `[mm:ss.xx] line`, one or more stamps per line. User content: never
/// log it, never save it.
struct SyncedLyrics: Equatable, Sendable {
    struct Line: Equatable, Sendable {
        /// Seconds from the start of the track.
        var time: TimeInterval
        /// Empty for an instrumental gap.
        var text: String
    }

    /// In time order.
    let lines: [Line]

    /// Parses LRC. Lines without a time stamp (metadata such as `[ar:…]`, or plain text) are skipped. Nil when nothing
    /// has a time stamp, so plain lyrics never pass for synced ones.
    init?(lrc: String) {
        var lines: [Line] = []
        for raw in lrc.split(whereSeparator: \.isNewline) {
            var rest = Substring(raw)
            var times: [TimeInterval] = []
            while let time = Self.leadingStamp(&rest) { times.append(time) }
            let text = rest.trimmingCharacters(in: .whitespaces)
            lines += times.map { Line(time: $0, text: text) }
        }
        guard !lines.isEmpty else { return nil }
        // Stable for equal times, so a line keeps its place in the file.
        self.lines = lines.enumerated().sorted { ($0.element.time, $0.offset) < ($1.element.time, $1.offset) }.map(\.element)
    }

    /// The line playing at `seconds`: the last one that has started. Nil before the first.
    func line(at seconds: TimeInterval) -> Line? {
        // Binary search: the first line that starts after `seconds`, then one back.
        var low = 0, high = lines.count
        while low < high {
            let mid = (low + high) / 2
            if lines[mid].time <= seconds { low = mid + 1 } else { high = mid }
        }
        return low == 0 ? nil : lines[low - 1]
    }

    /// Start times after `seconds`, for the view's redraw schedule.
    func starts(after seconds: TimeInterval) -> [TimeInterval] {
        lines.lazy.map(\.time).filter { $0 > seconds }
    }

    /// `[mm:ss]`, `[mm:ss.x]`, `[mm:ss.xx]` or `[mm:ss.xxx]` at the start of `text`, removed from it.
    private static func leadingStamp(_ text: inout Substring) -> TimeInterval? {
        guard text.first == "[", let close = text.firstIndex(of: "]") else { return nil }
        let inside = text[text.index(after: text.startIndex)..<close]
        let parts = inside.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, (1...3).contains(parts[0].count), parts[0].allSatisfy(\.isASCII),
              let minutes = Int(parts[0]), let seconds = Double(parts[1]), parts[1].first?.isNumber == true,
              seconds >= 0, seconds < 60 else { return nil }
        text = text[text.index(after: close)...]
        return TimeInterval(minutes * 60) + seconds
    }
}
