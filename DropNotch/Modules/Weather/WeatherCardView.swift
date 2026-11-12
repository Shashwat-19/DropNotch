import SwiftUI

/// The Weather card (D53): condition and temperature, the city, today's high and low, and the US AQI with its band in
/// words, so nothing rests on colour alone (L6). VoiceOver reads it as one sentence.
struct WeatherCardView: View {
    let module: WeatherModule
    @Environment(\.notchSize) private var size

    var body: some View {
        Group {
            if module.place == nil {
                NotchEmptyState("Choose a city in Settings › Weather", systemImage: "location.magnifyingglass")
            } else if let reading = module.reading, let place = module.place {
                content(reading, place)
            } else if module.failed {
                NotchEmptyState("Weather unavailable", systemImage: "cloud.slash")
            } else {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { module.didOpen() }
    }

    private func content(_ reading: WeatherReading, _ place: WeatherPlace) -> some View {
        let condition = reading.condition
        return VStack(spacing: NotchStyle.tightSpacing) {
            HStack(spacing: NotchStyle.tightSpacing) {
                Image(systemName: condition.systemImage)
                    .symbolRenderingMode(.multicolor)
                    .font(.notch(.title3, size))
                Text(WeatherReading.format(reading.temperature))
                    .font(.notch(.title2, size).weight(.semibold).monospacedDigit())
            }
            Text(place.name)
                .font(.notch(.subheadline, size).weight(.medium))
            if let high = reading.high, let low = reading.low {
                Text("H \(WeatherReading.format(high))  L \(WeatherReading.format(low))")
                    .font(.notch(.subheadline, size).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if let aqi = reading.airQuality, let level = reading.airQualityLevel {
                HStack(spacing: NotchStyle.tightSpacing) {
                    Circle().fill(level.colour).frame(width: 6, height: 6)
                    Text("AQI \(aqi) \(level.shortName)")
                }
                .font(.notch(.subheadline, size).monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText(reading, place)))
    }

    private func accessibilityText(_ reading: WeatherReading, _ place: WeatherPlace) -> String {
        var parts = ["\(place.name): \(WeatherReading.format(reading.temperature)), \(reading.condition.description)"]
        if let high = reading.high, let low = reading.low {
            parts.append(String(localized: "High \(WeatherReading.format(high)), low \(WeatherReading.format(low))"))
        }
        if let aqi = reading.airQuality, let level = reading.airQualityLevel {
            parts.append(String(localized: "Air quality \(aqi), \(level.name)"))
        }
        return parts.joined(separator: ". ")
    }
}

extension AirQualityLevel {
    /// The EPA's band colours, softened for a black background; the band is always in words too.
    var colour: Color {
        switch self {
        case .good: .green
        case .moderate: .yellow
        case .sensitive: .orange
        case .unhealthy: .red
        case .veryUnhealthy: .purple
        case .hazardous: Color(red: 0.6, green: 0.1, blue: 0.2)
        }
    }
}
