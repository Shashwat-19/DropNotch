/// Placeholder until a real source exists (Phase 3): never reports anything.
struct NoNowPlayingSource: NowPlayingSource {
    var updates: AsyncStream<NowPlayingInfo?> { AsyncStream { _ in } }
}
