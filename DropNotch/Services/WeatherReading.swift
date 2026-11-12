import Foundation

/// One weather and air-quality reading for the Weather card (D53). Temperatures are in °C, as Open-Meteo sends them;
/// the card converts to the user's unit.
struct WeatherReading: Equatable, Sendable {
    var temperature: Double
    var high: Double?
    var low: Double?
    /// WMO weather interpretation code, as Open-Meteo reports it.
    var code: Int
    var isDay: Bool
    /// US AQI; nil when the air-quality service had nothing or failed.
    var airQuality: Int?
    /// Set by the module when the reading arrives; drives the 30-minute refresh (D53).
    var fetchedAt = Date.distantPast

    var condition: WeatherCondition { WeatherCondition(code: code, isDay: isDay) }
    var airQualityLevel: AirQualityLevel? { airQuality.map(AirQualityLevel.init(usAQI:)) }

    /// "19°" in the user's unit, °C or °F by locale as the system's own weather does, without the scale letter: the
    /// narrow card has no room for it.
    static func format(_ celsius: Double, locale: Locale = .autoupdatingCurrent) -> String {
        Measurement(value: celsius, unit: UnitTemperature.celsius)
            .formatted(.measurement(width: .narrow, usage: .weather, hidesScaleName: true,
                                     numberFormatStyle: .number.precision(.fractionLength(0)))
                .locale(locale))
    }
}

/// A WMO weather code as a symbol and a short description.
struct WeatherCondition: Equatable {
    let systemImage: String
    let description: String

    init(code: Int, isDay: Bool) {
        switch code {
        case 0: (systemImage, description) = (isDay ? "sun.max.fill" : "moon.stars.fill", String(localized: "Clear"))
        case 1: (systemImage, description) = (isDay ? "sun.max.fill" : "moon.fill", String(localized: "Mainly clear"))
        case 2: (systemImage, description) = (isDay ? "cloud.sun.fill" : "cloud.moon.fill", String(localized: "Partly cloudy"))
        case 3: (systemImage, description) = ("cloud.fill", String(localized: "Overcast"))
        case 45, 48: (systemImage, description) = ("cloud.fog.fill", String(localized: "Fog"))
        case 51, 53, 55: (systemImage, description) = ("cloud.drizzle.fill", String(localized: "Drizzle"))
        case 56, 57, 66, 67: (systemImage, description) = ("cloud.sleet.fill", String(localized: "Freezing rain"))
        case 61, 63: (systemImage, description) = ("cloud.rain.fill", String(localized: "Rain"))
        case 65: (systemImage, description) = ("cloud.heavyrain.fill", String(localized: "Heavy rain"))
        case 71, 73, 75, 77: (systemImage, description) = ("cloud.snow.fill", String(localized: "Snow"))
        case 80, 81, 82: (systemImage, description) = (isDay ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill",
                                                       String(localized: "Showers"))
        case 85, 86: (systemImage, description) = ("cloud.snow.fill", String(localized: "Snow showers"))
        case 95: (systemImage, description) = ("cloud.bolt.rain.fill", String(localized: "Thunderstorm"))
        case 96, 99: (systemImage, description) = ("cloud.hail.fill", String(localized: "Thunderstorm with hail"))
        default: (systemImage, description) = ("cloud.fill", String(localized: "Unknown"))
        }
    }
}

/// The US AQI's six bands, as published by the US EPA.
enum AirQualityLevel: Equatable, CaseIterable {
    case good, moderate, sensitive, unhealthy, veryUnhealthy, hazardous

    init(usAQI: Int) {
        switch usAQI {
        case ..<51: self = .good
        case 51...100: self = .moderate
        case 101...150: self = .sensitive
        case 151...200: self = .unhealthy
        case 201...300: self = .veryUnhealthy
        default: self = .hazardous
        }
    }

    /// Short enough for the narrow card.
    var shortName: String {
        switch self {
        case .good: String(localized: "Good")
        case .moderate: String(localized: "Moderate")
        case .sensitive: String(localized: "Sensitive")
        case .unhealthy: String(localized: "Unhealthy")
        case .veryUnhealthy: String(localized: "Very unhealthy")
        case .hazardous: String(localized: "Hazardous")
        }
    }

    /// The band's full name, for VoiceOver.
    var name: String {
        self == .sensitive ? String(localized: "Unhealthy for sensitive groups") : shortName
    }
}
