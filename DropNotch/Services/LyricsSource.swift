import Foundation

/// Where Now Playing gets synced lyrics (D53). Tests use a fake; the app uses `LRCLibClient`.
protocol LyricsSource: Sendable {
    /// Synced lyrics for the track, or nil when there are none (not found, instrumental, or plain text only).
    /// Throws for a failure that's worth trying again later (network, server error).
    func lyrics(title: String, artist: String, duration: TimeInterval?) async throws -> SyncedLyrics?
}
