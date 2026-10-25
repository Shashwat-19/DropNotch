import Foundation

/// Which player the notch shows (D24). A pure value type: the source feeds it events and reads `current`.
struct NowPlayingSelection {
    private var players: [MediaPlayer: NowPlayingInfo] = [:]
    /// When each player last reported a state, as a counter: higher is more recent.
    private var reportedAt: [MediaPlayer: Int] = [:]
    private var clock = 0

    /// The most recent player to report playing; else the most recent to report anything, so pausing
    /// doesn't hand over; else a running player with unknown state, Music first; else nil.
    var current: NowPlayingInfo? {
        let known = players.values.filter { $0.state != .unknown }
        let older = { (a: NowPlayingInfo, b: NowPlayingInfo) in
            reportedAt[a.player, default: 0] < reportedAt[b.player, default: 0]
        }
        return known.filter(\.isPlaying).max(by: older)
            ?? known.max(by: older)
            ?? MediaPlayer.allCases.lazy.compactMap { players[$0] }.first
    }

    /// The player is running but hasn't reported yet (it just launched, or was running at start).
    mutating func launched(_ player: MediaPlayer) {
        if players[player] == nil { players[player] = NowPlayingInfo(player: player, state: .unknown) }
    }

    mutating func quit(_ player: MediaPlayer) {
        players[player] = nil
        reportedAt[player] = nil
    }

    /// A notification. With `carriesTrack: false` (a state-only payload) every track field stays (D24, D26).
    /// For the same track, what the payload didn't carry (Music sends no position) stays too; a new track
    /// starts with only what the payload carried.
    mutating func report(_ info: NowPlayingInfo, carriesTrack: Bool, at now: Date = Date()) {
        var info = info
        let last = players[info.player]
        if !carriesTrack {
            // A state-only payload for a player that isn't known to be running is most likely its quit
            // notice arriving after NSWorkspace's; keeping it would leave a player that never clears (D24).
            guard let last else { return }
            let state = info.state
            info = last
            info.state = state
            info.position = Self.anchor(last, at: now)
        } else if let last, info.trackID != nil, info.trackID == last.trackID {
            info.duration = info.duration ?? last.duration
            info.position = info.position ?? Self.anchor(last, at: now)
            info.artworkURL = info.artworkURL ?? last.artworkURL
            info.artwork = info.artwork ?? last.artwork
        }
        players[info.player] = info
        clock += 1
        reportedAt[info.player] = clock
    }

    /// What `player` last reported, merged with its reads.
    func info(for player: MediaPlayer) -> NowPlayingInfo? { players[player] }

    /// The counter value of `player`'s last report. A read records it when it starts (D26).
    func stamp(for player: MediaPlayer) -> Int? { reportedAt[player] }

    /// An Apple Event read after a notification, an open or a seek (D26), merged only while the player is on
    /// the same track. The track's own facts (duration, artwork URL) always merge; the position only if no
    /// report arrived since `stamp`, because a newer report has a newer position. It isn't a report, so it
    /// can't change which player is on screen.
    mutating func refreshed(_ read: NowPlayingInfo, stamp: Int?) {
        guard var info = players[read.player], read.trackID == info.trackID else { return }
        info.duration = read.duration ?? info.duration
        info.artworkURL = read.artworkURL ?? info.artworkURL
        if reportedAt[read.player] == stamp { info.position = read.position ?? info.position }
        players[read.player] = info
    }

    /// Artwork arrives after its track's notification: kept only if that player is still on the same track.
    mutating func setArtwork(_ artwork: NowPlayingArtwork, for player: MediaPlayer) {
        guard players[player]?.trackID == artwork.trackID else { return }
        players[player]?.artwork = artwork
    }

    /// Where the last position has got to by `now`, as a new anchor: frozen if it was paused.
    private static func anchor(_ info: NowPlayingInfo, at now: Date) -> PlaybackPosition? {
        info.elapsed(at: now).map { PlaybackPosition(seconds: $0, at: now) }
    }

    /// The one-off read at start (D23). Dropped if a notification came first (it is newer) or the player quit.
    @discardableResult
    mutating func fetched(_ info: NowPlayingInfo) -> Bool {
        guard players[info.player]?.state == .unknown else { return false }
        report(info, carriesTrack: true)
        return true
    }
}
