import Foundation
import os

/// `WeatherSource` from Open-Meteo's free APIs (D53): geocoding, forecast and air quality. No key, no account.
/// Like `ArtworkDownloader` (D25): an ephemeral session with no cookies, cache or credentials, no redirects, HTTPS to
/// three fixed hosts, and small responses only. Logs status codes only, never the city or coordinates.
struct OpenMeteoClient: WeatherSource {
    static let geocodingHost = "geocoding-api.open-meteo.com"
    static let forecastHost = "api.open-meteo.com"
    static let airQualityHost = "air-quality-api.open-meteo.com"
    /// A reply is a few hundred bytes [V: curl, 2026-11-13]; anything near this is not what we asked for.
    static let maxBytes = 256 * 1024
    /// Open-Meteo asks API users to identify themselves; this names the app and where it lives.
    static let userAgent = "DropNotch (+https://github.com/Shashwat-19/DropNotch)"

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
        configuration.httpAdditionalHeaders = ["User-Agent": Self.userAgent]
        if let protocolClasses { configuration.protocolClasses = protocolClasses }
        session = URLSession(configuration: configuration, delegate: RedirectRefuser(), delegateQueue: nil)
    }

    func places(matching name: String) async throws -> [WeatherPlace] {
        let query = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...100).contains(query.count) else { throw WeatherError.invalidQuery }
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        let url = Self.url(Self.geocodingHost, "/v1/search", ["name": query, "count": "5", "language": language,
                                                               "format": "json"])
        let reply: GeocodingReply = try await get(url)
        return (reply.results ?? []).map {
            WeatherPlace(name: $0.name, region: $0.admin1, country: $0.country, latitude: $0.latitude,
                         longitude: $0.longitude)
        }
    }

    func reading(at place: WeatherPlace) async throws -> WeatherReading {
        let at = ["latitude": String(place.latitude), "longitude": String(place.longitude)]
        let forecastURL = Self.url(Self.forecastHost, "/v1/forecast", at.merging([
            "current": "temperature_2m,weather_code,is_day", "daily": "temperature_2m_max,temperature_2m_min",
            "timezone": "auto", "forecast_days": "1"]) { $1 })
        let airURL = Self.url(Self.airQualityHost, "/v1/air-quality", at.merging(["current": "us_aqi"]) { $1 })
        // Both at once. Air quality is extra: if it fails, the card still shows the weather.
        async let air: AirQualityReply? = try? get(airURL)
        let forecast: ForecastReply = try await get(forecastURL)
        return WeatherReading(temperature: forecast.current.temperature_2m,
                              high: forecast.daily?.temperature_2m_max.first ?? nil,
                              low: forecast.daily?.temperature_2m_min.first ?? nil,
                              code: forecast.current.weather_code, isDay: forecast.current.is_day != 0,
                              airQuality: await air?.current.us_aqi.map { Int($0.rounded()) })
    }

    /// Internal for tests.
    static func url(_ host: String, _ path: String, _ query: [String: String]) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        // Sorted, so the same request always has the same URL.
        components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        // Only fails for a malformed path, and these paths are constants.
        return components.url!
    }

    private func get<Reply: Decodable>(_ url: URL) async throws -> Reply {
        let (data, response) = try await session.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            Logger.weather.error("Open-Meteo replied \(status) from \(url.host() ?? "?", privacy: .public)")
            throw WeatherError.badResponse(status: status)
        }
        guard data.count <= Self.maxBytes else { throw WeatherError.tooLarge }
        return try JSONDecoder().decode(Reply.self, from: data)
    }

    // The replies' shapes, as seen with curl (2026-11-13). Names match Open-Meteo's JSON keys.
    private struct GeocodingReply: Decodable {
        struct Result: Decodable {
            let name: String
            let latitude: Double
            let longitude: Double
            let country: String?
            let admin1: String?
        }
        /// Missing, not empty, when nothing matches [V: curl].
        let results: [Result]?
    }

    private struct ForecastReply: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let weather_code: Int
            let is_day: Int
        }
        struct Daily: Decodable {
            let temperature_2m_max: [Double?]
            let temperature_2m_min: [Double?]
        }
        let current: Current
        let daily: Daily?
    }

    private struct AirQualityReply: Decodable {
        struct Current: Decodable {
            let us_aqi: Double?
        }
        let current: Current
    }
}
