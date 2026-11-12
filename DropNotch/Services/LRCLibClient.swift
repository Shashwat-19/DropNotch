import Foundation
import os

/// `LyricsSource` from LRCLIB's public API (D53): `GET https://lrclib.net/api/get` with the title, artist and
/// duration. One request per track, only while the setting is on and the Now Playing card is on screen. Like
/// `ArtworkDownloader` (D25): ephemeral, no redirects, one host, a size cap. Logs status codes only.
struct LRCLibClient: LyricsSource {
    static let host = "lrclib.net"
    /// A song's LRC is a few KB [V: curl, 2026-11-13].
    static let maxBytes = 512 * 1024
    /// LRCLIB asks clients to name themselves.
    static let userAgent = OpenMeteoClient.userAgent
    /// Settings › Privacy › Show synced lyrics. Off when nothing is saved (D53).
    static let enabledKey = "lyrics.enabled"

    let session: URLSession

    init(protocolClasses: [AnyClass]? = nil) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 15
        configuration.waitsForConnectivity = false
        configuration.httpAdditionalHeaders = ["User-Agent": Self.userAgent]
        if let protocolClasses { configuration.protocolClasses = protocolClasses }
        session = URLSession(configuration: configuration, delegate: RedirectRefuser(), delegateQueue: nil)
    }

    func lyrics(title: String, artist: String, duration: TimeInterval?) async throws -> SyncedLyrics? {
        var query = ["track_name": title, "artist_name": artist]
        // Whole seconds: LRCLIB matches the duration within a couple of seconds.
        if let duration, duration > 0 { query["duration"] = String(Int(duration.rounded())) }
        let url = OpenMeteoClient.url(Self.host, "/api/get", query)
        let (data, response) = try await session.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        // 404 is LRCLIB's "no such track" [V: curl, 2026-11-13]: an answer, not a failure.
        if status == 404 { return nil }
        guard status == 200 else {
            Logger.nowPlaying.error("LRCLIB replied \(status)")
            throw ServiceError.badResponse(status: status)
        }
        guard data.count <= Self.maxBytes else { throw ServiceError.tooLarge }
        let reply = try JSONDecoder().decode(Reply.self, from: data)
        guard reply.instrumental != true, let lrc = reply.syncedLyrics else { return nil }
        return SyncedLyrics(lrc: lrc)
    }

    private struct Reply: Decodable {
        let instrumental: Bool?
        let syncedLyrics: String?
    }
}
