import Foundation

/// Reads a player's distributed-notification payload (D24). Pure, so it is tested without the players.
enum PlayerNotificationParser {
    /// nil when the payload has no state we know. `carriesTrack` is false when the payload has only
    /// `Player State` (Music between tracks, launch, quit): the caller keeps the last track.
    static func parse(_ userInfo: [AnyHashable: Any]?, from player: MediaPlayer)
        -> (info: NowPlayingInfo, carriesTrack: Bool)? {
        guard let userInfo, let state = state(userInfo["Player State"]) else { return nil }
        guard userInfo["Name"] != nil else { return (NowPlayingInfo(player: player, state: state), false) }
        // A Spotify ad's name and artist are ad copy, not a track [I: device check 14].
        if (userInfo["Track ID"] as? String)?.hasPrefix("spotify:ad:") == true {
            return (NowPlayingInfo(player: player, state: state), true)
        }
        let info = NowPlayingInfo(player: player, state: state,
                                  title: text(userInfo["Name"]), artist: text(userInfo["Artist"]))
        return (info, true)
    }

    /// Trimmed text, or nil when it is missing, not a string, or empty, so the view never shows a blank title.
    static func text(_ value: Any?) -> String? {
        guard let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        return text
    }

    private static func state(_ value: Any?) -> NowPlayingInfo.State? {
        switch value as? String {
        case "Playing": .playing
        case "Paused": .paused
        case "Stopped": .stopped
        default: nil
        }
    }
}
