import Foundation

/// Sends Apple Events to a running player, addressed by pid (D22, D23). A protocol so the source is
/// tested without real players or prompts.
protocol AppleEventSending: Sendable {
    /// Whether DropNotch may control the app at `pid`. `ask: false` never prompts; `ask: true` may show
    /// the system Automation prompt and waits for the answer.
    func permission(for player: MediaPlayer, pid: pid_t, ask: Bool) async -> AppleEventOutcome
    func send(_ command: PlaybackCommand, to player: MediaPlayer, pid: pid_t) async -> AppleEventOutcome
    /// The player's state and track (title, artist, id, duration, position; Spotify's artwork URL), or nil
    /// if the state can't be read. Call it only after `permission(ask: false)` returned `.ok`, so it can't prompt.
    func readCurrent(of player: MediaPlayer, pid: pid_t) async -> NowPlayingInfo?
    /// Music's artwork bytes for the current track (nil for Spotify, none, or too large). Same rule as
    /// `readCurrent`: only after `permission(ask: false)` returned `.ok`.
    func readArtwork(of player: MediaPlayer, pid: pid_t) async -> Data?
}
