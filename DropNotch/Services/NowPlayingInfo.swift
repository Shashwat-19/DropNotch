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

    var isPlaying: Bool { state == .playing }
}
