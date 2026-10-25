import Foundation

/// Reads a player's distributed-notification payload (D24). Pure, so it is tested without the players.
enum PlayerNotificationParser {
    /// nil when the payload has no state we know. `carriesTrack` is false when the payload has only
    /// `Player State` (Music between tracks, launch, quit): the caller keeps the last track.
    /// `now` anchors Spotify's position: the moment the notification arrived.
    static func parse(_ userInfo: [AnyHashable: Any]?, from player: MediaPlayer, at now: Date = Date())
        -> (info: NowPlayingInfo, carriesTrack: Bool)? {
        guard let userInfo, let state = state(userInfo["Player State"]) else { return nil }
        guard userInfo["Name"] != nil else { return (NowPlayingInfo(player: player, state: state), false) }
        // Units from the probe (D26): both durations are milliseconds; Spotify's position is seconds.
        let info = switch player {
        case .music:
            track(player, state, name: userInfo["Name"], artist: userInfo["Artist"],
                  trackID: musicTrackID(userInfo["PersistentID"]),
                  duration: seconds(userInfo["Total Time"], unit: 1000))
        case .spotify:
            track(player, state, name: userInfo["Name"], artist: userInfo["Artist"], trackID: userInfo["Track ID"],
                  duration: seconds(userInfo["Duration"], unit: 1000),
                  position: seconds(userInfo["Playback Position"], unit: 1), at: now)
        }
        return (info, true)
    }

    /// One track's info, from values already in seconds. Shared with the Apple Event read
    /// (`AppleEventSender`), so both apply the same rules.
    static func track(_ player: MediaPlayer, _ state: NowPlayingInfo.State, name: Any?, artist: Any?, trackID: Any?,
                      duration: TimeInterval? = nil, position: TimeInterval? = nil, at now: Date = Date()) -> NowPlayingInfo {
        let id = text(trackID)
        let anchor = position.map { PlaybackPosition(seconds: $0, at: now) }
        // A Spotify ad's name, artist and id are ad copy, not a track [I: device check 14]. No id means no artwork.
        if id?.hasPrefix("spotify:ad:") == true {
            return NowPlayingInfo(player: player, state: state, duration: duration, position: anchor)
        }
        return NowPlayingInfo(player: player, state: state, title: text(name), artist: text(artist),
                              trackID: id, duration: duration, position: anchor)
    }

    /// A finite, non-negative number divided by `unit` (1000 for milliseconds); nil for anything else,
    /// so a bad value means "unknown", never zero (D26).
    static func seconds(_ value: Any?, unit: Double) -> TimeInterval? {
        guard let number = (value as? NSNumber)?.doubleValue, number.isFinite, number >= 0 else { return nil }
        return number / unit
    }

    /// Music's `PersistentID` (a signed 64-bit number) as the upper-case hex its `persistent ID` property
    /// reads, so notifications and Apple Event reads give the same id [V: probe].
    static func musicTrackID(_ value: Any?) -> String? {
        (value as? NSNumber).map { String(format: "%016llX", UInt64(bitPattern: $0.int64Value)) }
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
