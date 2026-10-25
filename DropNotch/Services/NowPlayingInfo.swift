import Foundation

/// What a `NowPlayingSource` reports for the player on screen. Track details are user content: never log them.
struct NowPlayingInfo: Equatable {
    enum State {
        /// Running, but no notification yet and no permission to read it (D23).
        case unknown
        case playing, paused, stopped
    }

    var player: MediaPlayer
    var state: State
    /// nil when the player didn't say (an ad, a stream, or no notification yet); the view shows the player's name.
    var title: String?
    var artist: String?
    /// Stable per track (D26): Music's persistent ID as upper-case hex, Spotify's track id. User content: never log.
    var trackID: String?
    /// Seconds, whatever unit the player reported (D26).
    var duration: TimeInterval?
    var position: PlaybackPosition?
    /// Spotify only, read by Apple Event; fetched once per track (D25). Never log.
    var artworkURL: URL?

    var isPlaying: Bool { state == .playing }

    /// Seconds into the track at `now`, or nil when the position isn't known.
    func elapsed(at now: Date) -> TimeInterval? {
        position?.elapsed(at: now, isPlaying: isPlaying, duration: duration)
    }
}
