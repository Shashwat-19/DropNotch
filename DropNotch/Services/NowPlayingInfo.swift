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
    /// The thumbnail for `trackID`, once read (Music) or fetched (Spotify); nil shows the app icon.
    var artwork: NowPlayingArtwork?
    /// The artwork load for `trackID` finished without a picture: the view shows the app icon (D27).
    var artworkMissing = false

    var isPlaying: Bool { state == .playing }

    /// Seconds into the track at `now`, or nil when the position isn't known.
    func elapsed(at now: Date) -> TimeInterval? {
        position?.elapsed(at: now, isPlaying: isPlaying, duration: duration)
    }

    /// This info as the view should draw it after `shown` (D27). On the same track, a position that is missing,
    /// or within a second of where `shown` has got to by `now`, carries on from `shown`: while paused either
    /// way (a pause stays where it froze), while playing only backwards. Music's position reads lag and
    /// jitter by a few tenths of a second [V: probe, 2026-10-31]; a seek moves further.
    func steadied(after shown: NowPlayingInfo?, at now: Date) -> NowPlayingInfo {
        guard let shown, shown.player == player, let trackID, trackID == shown.trackID,
              let shownSeconds = shown.elapsed(at: now) else { return self }
        if let seconds = elapsed(at: now) {
            let delta = seconds - shownSeconds
            guard abs(delta) < Self.steadyTolerance, delta < 0 || !isPlaying else { return self }
        }
        var steadied = self
        steadied.position = PlaybackPosition(seconds: shownSeconds, at: now)
        return steadied
    }

    static let steadyTolerance: TimeInterval = 1
}
