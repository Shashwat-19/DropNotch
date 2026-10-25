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

    /// A notification. With `carriesTrack: false` (a state-only payload) the last title and artist stay.
    mutating func report(_ info: NowPlayingInfo, carriesTrack: Bool) {
        var info = info
        if !carriesTrack, let last = players[info.player] {
            info.title = last.title
            info.artist = last.artist
        }
        players[info.player] = info
        clock += 1
        reportedAt[info.player] = clock
    }

    /// The one-off read at start (D23). Dropped if a notification came first (it is newer) or the player quit.
    mutating func fetched(_ info: NowPlayingInfo) {
        guard players[info.player]?.state == .unknown else { return }
        report(info, carriesTrack: true)
    }
}
