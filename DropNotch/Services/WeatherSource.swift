/// Where the Weather card gets places and readings (D53). Tests use a fake; the app uses `OpenMeteoClient`.
protocol WeatherSource: Sendable {
    /// Places whose name matches, best first. Empty when nothing matches.
    func places(matching name: String) async throws -> [WeatherPlace]
    /// Current weather and today's high and low at `place`, with air quality when available.
    func reading(at place: WeatherPlace) async throws -> WeatherReading
}

enum WeatherError: Error, Equatable {
    case badResponse(status: Int)
    case tooLarge
    case invalidQuery
}
