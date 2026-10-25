import CoreServices
import Foundation

/// A player DropNotch reads through its notifications and controls with Apple Events (D22, D24).
/// Names and codes were checked on 2026-10-25 (docs/research/now-playing-probe-2026-10-25.md).
enum MediaPlayer: CaseIterable {
    case music, spotify

    var bundleID: String {
        switch self {
        case .music: "com.apple.Music"
        case .spotify: "com.spotify.client"
        }
    }

    /// Posted by the player on every state or track change. Undocumented, so a player update can rename it.
    var notificationName: Notification.Name {
        switch self {
        case .music: Notification.Name("com.apple.Music.playerInfo")
        case .spotify: Notification.Name("com.spotify.client.PlaybackStateChanged")
        }
    }

    /// Shown when there is no title, and in the permission text. App names stay untranslated.
    var displayName: String {
        switch self {
        case .music: "Music"
        case .spotify: "Spotify"
        }
    }

    /// The Apple Event for a command, from the player's scripting dictionary (`sdef`).
    func event(for command: PlaybackCommand) -> (eventClass: AEEventClass, eventID: AEEventID) {
        let suite = self == .music ? "hook" : "spfy"
        let id = switch command {
        case .playPause: "PlPs"
        case .next: "Next"
        // Music's "back track" restarts the current track first, like a Previous button (D22).
        case .previous: self == .music ? "Back" : "Prev"
        }
        return (FourCharCode(code: suite), FourCharCode(code: id))
    }
}

enum PlaybackCommand {
    case playPause, next, previous
}
