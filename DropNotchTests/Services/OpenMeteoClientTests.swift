import XCTest
@testable import DropNotch

final class OpenMeteoClientTests: XCTestCase {
    /// Answers by host; records each request. Static because URLSession creates the protocol instances.
    private final class Stub: URLProtocol {
        nonisolated(unsafe) static var replies: [String: (status: Int, body: String)] = [:]
        nonisolated(unsafe) static var requests: [URLRequest] = []
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            Self.requests.append(request)
            let reply = Self.replies[request.url?.host() ?? ""] ?? (404, "")
            let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(reply.body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    // Trimmed from real replies (curl, 2026-11-13).
    private let geocoding = #"{"results":[{"id":1277333,"name":"Bengaluru","latitude":12.97194,"longitude":77.59369,"country":"India","admin1":"Karnataka"},{"id":2,"name":"Bengaluru Rural","latitude":13.2,"longitude":77.7}],"generationtime_ms":0.1}"#
    private let forecast = #"{"latitude":12.97,"current":{"time":"2026-11-13T00:30","interval":900,"temperature_2m":19.0,"weather_code":1,"is_day":0},"daily":{"time":["2026-11-13"],"temperature_2m_max":[28.5],"temperature_2m_min":[17.2]}}"#
    private let air = #"{"latitude":13.0,"current":{"time":"2026-11-12T19:00","interval":3600,"us_aqi":98}}"#

    private let place = WeatherPlace(name: "Bengaluru", region: "Karnataka", country: "India",
                                     latitude: 12.97194, longitude: 77.59369)

    override func setUp() {
        super.setUp()
        Stub.replies = [:]
        Stub.requests = []
    }

    private func client() -> OpenMeteoClient { OpenMeteoClient(protocolClasses: [Stub.self]) }

    func testSearchParsesPlacesAndRoundsTheirCoordinates() async throws {
        Stub.replies[OpenMeteoClient.geocodingHost] = (200, geocoding)
        let places = try await client().places(matching: "  Bengaluru ")
        XCTAssertEqual(places.map(\.fullName), ["Bengaluru, Karnataka, India", "Bengaluru Rural"])
        XCTAssertEqual(places.first?.latitude, 12.97)
        XCTAssertEqual(places.first?.longitude, 77.59)
        let url = try XCTUnwrap(Stub.requests.first?.url)
        XCTAssertEqual(url.scheme, "https")
        XCTAssertTrue(url.query()?.contains("name=Bengaluru") ?? false, "trimmed")
    }

    func testNoMatchIsAnEmptyListNotAnError() async throws {
        Stub.replies[OpenMeteoClient.geocodingHost] = (200, #"{"generationtime_ms":0.03}"#)
        let places = try await client().places(matching: "zzzzqqq")
        XCTAssertTrue(places.isEmpty)
    }

    func testEmptyOrHugeQueryIsRefusedWithoutARequest() async {
        for query in ["   ", String(repeating: "a", count: 101)] {
            do {
                _ = try await client().places(matching: query)
                XCTFail("should throw")
            } catch {
                XCTAssertEqual(error as? ServiceError, .invalidQuery)
            }
        }
        XCTAssertTrue(Stub.requests.isEmpty)
    }

    func testReadingCombinesForecastAndAirQualityAndSendsOnlyRoundedCoordinates() async throws {
        Stub.replies[OpenMeteoClient.forecastHost] = (200, forecast)
        Stub.replies[OpenMeteoClient.airQualityHost] = (200, air)
        let reading = try await client().reading(at: place)
        XCTAssertEqual(reading.temperature, 19)
        XCTAssertEqual(reading.high, 28.5)
        XCTAssertEqual(reading.low, 17.2)
        XCTAssertEqual(reading.code, 1)
        XCTAssertFalse(reading.isDay)
        XCTAssertEqual(reading.airQuality, 98)
        XCTAssertEqual(Set(Stub.requests.compactMap { $0.url?.host() }),
                       [OpenMeteoClient.forecastHost, OpenMeteoClient.airQualityHost])
        for request in Stub.requests {
            let query = request.url?.query() ?? ""
            XCTAssertTrue(query.contains("latitude=12.97&") && query.contains("longitude=77.59"), query)
            XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), OpenMeteoClient.userAgent)
        }
    }

    func testAirQualityFailureStillGivesTheWeather() async throws {
        Stub.replies[OpenMeteoClient.forecastHost] = (200, forecast)
        Stub.replies[OpenMeteoClient.airQualityHost] = (500, "")
        let reading = try await client().reading(at: place)
        XCTAssertEqual(reading.temperature, 19)
        XCTAssertNil(reading.airQuality)
    }

    func testForecastFailureThrowsTheStatus() async {
        Stub.replies[OpenMeteoClient.forecastHost] = (429, "")
        do {
            _ = try await client().reading(at: place)
            XCTFail("should throw")
        } catch {
            XCTAssertEqual(error as? ServiceError, .badResponse(status: 429))
        }
    }

    func testSessionKeepsNothing() {
        let configuration = client().session.configuration
        XCTAssertNil(configuration.httpCookieStorage)
        XCTAssertNil(configuration.urlCache)
        XCTAssertNil(configuration.urlCredentialStorage)
        XCTAssertTrue(client().session.delegate is RedirectRefuser)
    }
}

final class WeatherReadingTests: XCTestCase {
    func testConditionsCoverDayAndNight() {
        XCTAssertEqual(WeatherCondition(code: 0, isDay: true).systemImage, "sun.max.fill")
        XCTAssertEqual(WeatherCondition(code: 0, isDay: false).systemImage, "moon.stars.fill")
        XCTAssertEqual(WeatherCondition(code: 95, isDay: true).systemImage, "cloud.bolt.rain.fill")
        XCTAssertEqual(WeatherCondition(code: 1234, isDay: true).description, "Unknown")
    }

    func testAirQualityBandsFollowTheEPABoundaries() {
        let cases: [(Int, AirQualityLevel)] = [(0, .good), (50, .good), (51, .moderate), (100, .moderate),
                                               (101, .sensitive), (150, .sensitive), (151, .unhealthy),
                                               (200, .unhealthy), (201, .veryUnhealthy), (300, .veryUnhealthy),
                                               (301, .hazardous), (500, .hazardous)]
        for (aqi, level) in cases { XCTAssertEqual(AirQualityLevel(usAQI: aqi), level, "\(aqi)") }
    }

    func testTemperatureFollowsTheLocalesUnit() {
        XCTAssertEqual(WeatherReading.format(19, locale: Locale(identifier: "en_IN")), "19°")
        XCTAssertEqual(WeatherReading.format(19, locale: Locale(identifier: "en_US")), "66°")
    }

    func testPlaceRoundTripsThroughDefaults() throws {
        let name = "WeatherReadingTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let place = WeatherPlace(name: "Pune", region: nil, country: "India", latitude: 18.5196, longitude: 73.8554)
        WeatherPlace.save(place, defaults)
        XCTAssertEqual(WeatherPlace.saved(defaults), place)
        XCTAssertEqual(place.latitude, 18.52)
        XCTAssertEqual(place.fullName, "Pune, India")
        WeatherPlace.save(nil, defaults)
        XCTAssertNil(WeatherPlace.saved(defaults))
    }
}
