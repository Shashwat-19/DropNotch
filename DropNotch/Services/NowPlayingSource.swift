/// Where Now Playing gets its data (D2). Apple Music and Spotify sources come in Phase 3,
/// MediaRemote in v0.2; the module doesn't change when they arrive.
protocol NowPlayingSource {
    /// The current track, or nil when nothing is playing. Delivered when it changes, not polled.
    var updates: AsyncStream<NowPlayingInfo?> { get }
}
