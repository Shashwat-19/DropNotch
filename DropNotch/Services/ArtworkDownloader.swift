import Foundation

/// DropNotch's only network client (D25): Spotify artwork from `i.scdn.co`, one GET per track.
/// Nothing is stored: no cookies, no cache, no credentials, and the image is decoded in memory.
struct ArtworkDownloader: ArtworkLoading {
    static let allowedHost = "i.scdn.co"
    /// The probe saw 39–61 KB [V: media probe].
    static let maxBytes = 2 * 1024 * 1024
    static let imageTypes: Set<String> = ["image/jpeg", "image/png"]

    /// Internal so a test can check the configuration.
    let session: URLSession

    /// `protocolClasses` lets tests answer requests offline.
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
        if let protocolClasses { configuration.protocolClasses = protocolClasses }
        session = URLSession(configuration: configuration, delegate: RedirectRefuser(), delegateQueue: nil)
    }

    /// `https://i.scdn.co/...` and nothing else: no other scheme, host, port, or user name, which could
    /// hide a different host (`https://i.scdn.co@example.com/`).
    static func allows(_ url: URL) -> Bool {
        // The host as written: a percent-encoded host isn't decoded into a match (security-auditor L3).
        url.scheme?.lowercased() == "https" && url.host(percentEncoded: true)?.lowercased() == allowedHost
            && url.user == nil && url.password == nil && (url.port == nil || url.port == 443)
    }

    func data(from url: URL) async -> Data? {
        guard Self.allows(url) else { return nil }
        do {
            let (bytes, response) = try await session.bytes(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let type = http.mimeType?.lowercased(), Self.imageTypes.contains(type),
                  http.expectedContentLength <= Self.maxBytes else {
                bytes.task.cancel()
                return nil
            }
            // Counted while it arrives, so a server that lies about the length can't make us hold more.
            var data = Data()
            for try await byte in bytes {
                data.append(byte)
                if data.count > Self.maxBytes {
                    bytes.task.cancel()
                    return nil
                }
            }
            return data
        } catch {
            return nil
        }
    }
}

/// Refuses every redirect, so a request can only ever reach the allowed host (D25). Internal for tests.
final class RedirectRefuser: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
