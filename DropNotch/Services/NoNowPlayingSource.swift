/// A source with no players: never reports anything, and commands go nowhere. For tests and previews.
struct NoNowPlayingSource: NowPlayingSource {
    var updates: AsyncStream<NowPlayingInfo?> { AsyncStream { _ in } }
    func send(_ command: PlaybackCommand, to player: MediaPlayer) async -> AppleEventOutcome { .notRunning }
}
