/// Where Now Playing gets its data (D2). Music and Spotify come from `ScriptablePlayersSource` (D22–D24),
/// MediaRemote in v0.2; the module doesn't change when they arrive.
/// `@MainActor` because its only consumer is the module, which is UI state.
@MainActor
protocol NowPlayingSource {
    /// The player on screen, or nil when no player is running. Delivered when it changes, not polled.
    var updates: AsyncStream<NowPlayingInfo?> { get }
    /// May show the system Automation prompt for `player` the first time (D23).
    func send(_ command: PlaybackCommand, to player: MediaPlayer) async -> AppleEventOutcome
}
