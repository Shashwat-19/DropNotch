import Foundation

/// Where the playhead was at a moment (D26). Scripting reports no playback rate, so time runs at 1×.
struct PlaybackPosition: Equatable {
    var seconds: TimeInterval
    var at: Date

    /// The position at `now`: moving only while playing, never backwards if the clock is, within 0...duration.
    func elapsed(at now: Date, isPlaying: Bool, duration: TimeInterval?) -> TimeInterval {
        let moved = isPlaying ? max(0, now.timeIntervalSince(at)) : 0
        let value = max(0, seconds + moved)
        return duration.map { min(value, $0) } ?? value
    }
}
