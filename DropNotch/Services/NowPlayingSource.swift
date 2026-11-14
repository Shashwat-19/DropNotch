import CoreServices

/// Where Now Playing gets its data (D2). Music and Spotify come from `ScriptablePlayersSource` (D22–D24),
/// MediaRemote in v0.2; the module doesn't change when they arrive.
/// `@MainActor` because its only consumer is the module, which is UI state.
@MainActor
protocol NowPlayingSource {
    /// The player on screen, or nil when no player is running. Delivered when it changes, not polled.
    var updates: AsyncStream<NowPlayingInfo?> { get }
    /// May show the system Automation prompt for `player` the first time (D23).
    func send(_ command: PlaybackCommand, to player: MediaPlayer) async -> AppleEventOutcome
    /// Re-reads `player`'s position, where the source can and the user already allowed it; never prompts (D26).
    func refresh(_ player: MediaPlayer)
    /// Clears DropNotch's Automation record and asks for `player` again (D59): the way out of a denial macOS keeps for
    /// an older build, which System Settings shows as allowed. May show the system prompt.
    func renewPermission(for player: MediaPlayer) async -> AppleEventOutcome
}

extension NowPlayingSource {
    /// Sources without Automation have nothing to renew: the view falls back to System Settings.
    func renewPermission(for player: MediaPlayer) async -> AppleEventOutcome { .failed(OSStatus(unimpErr)) }
}
