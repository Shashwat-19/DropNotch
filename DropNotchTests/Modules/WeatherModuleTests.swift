import XCTest
@testable import DropNotch

@MainActor
final class WeatherModuleTests: XCTestCase {
    private final class FakeSource: WeatherSource, @unchecked Sendable {
        var readings = 0
        var fails = false
        func places(matching name: String) async throws -> [WeatherPlace] { [] }
        func reading(at place: WeatherPlace) async throws -> WeatherReading {
            readings += 1
            if fails { throw WeatherError.badResponse(status: 500) }
            return WeatherReading(temperature: 20, high: 25, low: 15, code: 0, isDay: true, airQuality: 40)
        }
    }

    private let pune = WeatherPlace(name: "Pune", region: nil, country: "India", latitude: 18.52, longitude: 73.86)
    private var suites: [String] = []
    private var clock = Date(timeIntervalSince1970: 1_000_000)

    private func makeDefaults(place: WeatherPlace? = nil) -> UserDefaults {
        let name = "WeatherModuleTests.\(UUID())"
        suites.append(name)
        let defaults = UserDefaults(suiteName: name)!
        WeatherPlace.save(place, defaults)
        return defaults
    }

    override func tearDown() {
        suites.forEach { UserDefaults(suiteName: $0)?.removePersistentDomain(forName: $0) }
        suites = []
        super.tearDown()
    }

    private func module(_ source: FakeSource, place: WeatherPlace?) -> WeatherModule {
        WeatherModule(source: source, defaults: makeDefaults(place: place)) { [unowned self] in self.clock }
    }

    func testIsAnOffByDefaultNarrowCard() {
        let module = module(FakeSource(), place: nil)
        XCTAssertEqual(module.id, "weather")
        XCTAssertEqual(module.homeCard, .narrow)
        XCTAssertFalse(module.isEnabledByDefault)
    }

    func testNoCityOrNotRunningMeansNoRequest() {
        let source = FakeSource()
        let withCity = module(source, place: pune)
        XCTAssertFalse(withCity.needsRefresh, "not started")
        let noCity = module(source, place: nil)
        noCity.start()
        XCTAssertFalse(noCity.needsRefresh)
        XCTAssertEqual(source.readings, 0)
    }

    func testFetchesOnceThenAgainOnlyAfterThirtyMinutes() async {
        let source = FakeSource()
        let module = module(source, place: pune)
        module.start()
        XCTAssertTrue(module.needsRefresh)
        await module.refresh()
        XCTAssertEqual(module.reading?.temperature, 20)
        XCTAssertEqual(module.reading?.fetchedAt, clock)
        clock += 29 * 60
        XCTAssertFalse(module.needsRefresh)
        clock += 2 * 60
        XCTAssertTrue(module.needsRefresh)
        await module.refresh()
        XCTAssertEqual(source.readings, 2)
    }

    func testFailureShowsAndRetriesAfterAMinute() async {
        let source = FakeSource()
        source.fails = true
        let module = module(source, place: pune)
        module.start()
        await module.refresh()
        XCTAssertTrue(module.failed)
        XCTAssertNil(module.reading)
        clock += 30
        XCTAssertFalse(module.needsRefresh)
        clock += 31
        XCTAssertTrue(module.needsRefresh)
        source.fails = false
        await module.refresh()
        XCTAssertFalse(module.failed)
        XCTAssertNotNil(module.reading)
    }

    func testStopClearsTheReadingAndChoosingACitySavesIt() async {
        let source = FakeSource()
        let module = module(source, place: nil)
        module.start()
        module.choose(pune)
        XCTAssertEqual(module.place, pune)
        for _ in 0..<1000 where module.reading == nil { await Task.yield() }
        XCTAssertNotNil(module.reading, "choosing a city with the card on fetches at once")
        module.stop()
        XCTAssertNil(module.reading)
        module.start()
        XCTAssertEqual(module.place, pune, "kept across a restart")
        module.choose(nil)
        XCTAssertNil(module.place)
        XCTAssertFalse(module.needsRefresh)
    }
}
