/// Synced lyrics and the track they belong to (D53), so the card never shows one track's lyrics over another's.
struct TrackLyrics: Equatable {
    let trackID: String
    let lyrics: SyncedLyrics
}
