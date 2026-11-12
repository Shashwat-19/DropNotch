import Foundation

/// The city chosen in Settings › Weather (D53). Only its rounded coordinates are ever sent anywhere.
struct WeatherPlace: Codable, Equatable, Sendable {
    var name: String
    /// State or region, e.g. "Karnataka"; nil when Open-Meteo has none.
    var region: String?
    var country: String?
    var latitude: Double
    var longitude: Double

    static let key = "weather.place"

    /// Coordinates are rounded to two decimals (about 1 km) before they're kept or sent (D53).
    init(name: String, region: String?, country: String?, latitude: Double, longitude: Double) {
        self.name = name
        self.region = region
        self.country = country
        self.latitude = Self.rounded(latitude)
        self.longitude = Self.rounded(longitude)
    }

    nonisolated static func rounded(_ degrees: Double) -> Double { (degrees * 100).rounded() / 100 }

    /// "Bengaluru, Karnataka, India", for telling places with the same name apart in Settings.
    var fullName: String { [name, region, country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ") }

    static func saved(_ defaults: UserDefaults = .standard) -> WeatherPlace? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(WeatherPlace.self, from: $0) }
    }

    static func save(_ place: WeatherPlace?, _ defaults: UserDefaults = .standard) {
        if let place, let data = try? JSONEncoder().encode(place) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
