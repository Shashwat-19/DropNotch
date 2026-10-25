import Foundation

/// Reads a player's distributed-notification payload (D24). Pure, so it is tested without the players.
enum PlayerNotificationParser {
    /// nil when the payload has no state we know. `carriesTrack` is false when the payload has only
    /// `Player State` (Music between tracks, launch, quit): the caller keeps the last track.
    static func parse(_ userInfo: [AnyHashable: Any]?, from player: MediaPlayer)
        -> (info: NowPlayingInfo, carriesTrack: Bool)? {
        guard let userInfo, let state = state(userInfo["Player State"]) else { return nil }
        guard userInfo["Name"] != nil else { return (NowPlayingInfo(player: player, state: state), false) }
        let info = track(player, state, name: userInfo["Name"], artist: userInfo["Artist"], trackID: userInfo["Track ID"])
        return (info, true)
    }

    /// One track's info. Shared with the read at start (`AppleEventSender`), so both apply the same rules.
    static func track(_ player: MediaPlayer, _ state: NowPlayingInfo.State,
                      name: Any?, artist: Any?, trackID: Any?) -> NowPlayingInfo {
        // A Spotify ad's name and artist are ad copy, not a track [I: device check 14].
        if (trackID as? String)?.hasPrefix("spotify:ad:") == true {
            return NowPlayingInfo(player: player, state: state)
        }
        return NowPlayingInfo(player: player, state: state, title: text(name), artist: text(artist))
    }

    /// Trimmed text, or nil when it is missing, not a string, or empty, so the view never shows a blank title.
    /// Capped, because any local process can post these notifications with any text.
    private static func text(_ value: Any?) -> String? {
        guard let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        return String(text.prefix(maxTextLength))
    }

    static let maxTextLength = 256

    private static func state(_ value: Any?) -> NowPlayingInfo.State? {
        switch value as? String {
        case "Playing": .playing
        case "Paused": .paused
        case "Stopped": .stopped
        default: nil
        }
    }
}
