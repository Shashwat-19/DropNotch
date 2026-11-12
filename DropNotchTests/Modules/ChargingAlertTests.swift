import IOKit.ps
import SwiftUI
import XCTest
@testable import DropNotch

@MainActor
final class ChargingAlertTests: XCTestCase {
    private final class FakeSource: BatterySource {
        let stream: AsyncStream<BatteryStatus?>
        private(set) var subscriptions = 0
        init(stream: AsyncStream<BatteryStatus?>) { self.stream = stream }
        var updates: AsyncStream<BatteryStatus?> {
            subscriptions += 1
            return stream
        }
    }

    private var suites: [String] = []

    private func makeDefaults() -> UserDefaults {
        let name = "ChargingAlertTests.\(UUID())"
        suites.append(name)
        return UserDefaults(suiteName: name)!
    }

    override func tearDown() {
        suites.forEach { UserDefaults(suiteName: $0)?.removePersistentDomain(forName: $0) }
        suites = []
        super.tearDown()
    }

    private func status(_ percent: Int, onPower: Bool, charging: Bool = false) -> BatteryStatus? {
        BatteryStatus(descriptions: [[kIOPSTypeKey: kIOPSInternalBatteryType, kIOPSCurrentCapacityKey: percent,
                                      kIOPSMaxCapacityKey: 100, kIOPSIsChargingKey: charging,
                                      kIOPSPowerSourceStateKey: onPower ? kIOPSACPowerValue : kIOPSBatteryPowerValue]])
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<1000 where !condition() { await Task.yield() }
    }

    func testOnlyAChangeFromBatteryToPowerCounts() {
        let battery = status(50, onPower: false), power = status(50, onPower: true, charging: true)
        XCTAssertTrue(ChargingAlert.justPluggedIn(previous: battery, current: power))
        XCTAssertFalse(ChargingAlert.justPluggedIn(previous: nil, current: power), "the first reading, at launch")
        XCTAssertFalse(ChargingAlert.justPluggedIn(previous: power, current: power), "already on power")
        XCTAssertFalse(ChargingAlert.justPluggedIn(previous: power, current: battery), "unplugged")
        XCTAssertFalse(ChargingAlert.justPluggedIn(previous: battery, current: nil))
        // A full battery on power isn't charging, but it was still just plugged in.
        XCTAssertTrue(ChargingAlert.justPluggedIn(previous: status(100, onPower: false), current: status(100, onPower: true)))
    }

    func testPluggingInShowsAHUDAndTapsOnce() async {
        let (stream, continuation) = AsyncStream.makeStream(of: BatteryStatus?.self)
        let registry = ModuleRegistry(modules: [], defaults: makeDefaults())
        var taps = 0
        let alert = ChargingAlert(source: FakeSource(stream: stream), registry: registry, defaults: makeDefaults()) { taps += 1 }
        alert.start()
        continuation.yield(status(40, onPower: true, charging: true))
        continuation.yield(status(40, onPower: false))
        await Task.yield()
        XCTAssertNil(registry.hud, "launching on power, then unplugging, shows nothing")
        continuation.yield(status(40, onPower: true, charging: true))
        await waitUntil { registry.hud != nil }
        XCTAssertNotNil(registry.hud)
        XCTAssertEqual(registry.compactWings, [.left, .right])
        XCTAssertEqual(registry.hud?.announcement, "Charging, \(40.formatted(.percent))")
        XCTAssertEqual(taps, 1)
        alert.stop()
    }

    func testTurnedOffItStopsFollowingTheBattery() {
        let defaults = makeDefaults()
        defaults.set(false, forKey: ChargingAlert.key)
        let source = FakeSource(stream: AsyncStream { _ in })
        let alert = ChargingAlert(source: source, registry: ModuleRegistry(modules: [], defaults: makeDefaults()),
                                  defaults: defaults) {}
        alert.refresh()
        XCTAssertFalse(alert.isRunning)
        defaults.set(true, forKey: ChargingAlert.key)
        alert.refresh()
        XCTAssertTrue(alert.isRunning)
        alert.refresh()
        defaults.set(false, forKey: ChargingAlert.key)
        alert.refresh()
        XCTAssertFalse(alert.isRunning)
    }

    func testOnByDefault() {
        let alert = ChargingAlert(source: FakeSource(stream: AsyncStream { _ in }),
                                  registry: ModuleRegistry(modules: [], defaults: makeDefaults()), defaults: makeDefaults()) {}
        XCTAssertTrue(alert.isEnabled)
        XCTAssertTrue(Haptics.isEnabled(makeDefaults()))
    }

    func testHUDGoesAfterItsDurationAndANewOneRestartsIt() async throws {
        let registry = ModuleRegistry(modules: [], defaults: makeDefaults())
        XCTAssertEqual(registry.compactWings, [])
        let first = NotchHUD(leading: AnyView(EmptyView()), trailing: AnyView(EmptyView()), announcement: "One")
        registry.showHUD(first, for: .milliseconds(150))
        XCTAssertEqual(registry.hud, first)
        try await Task.sleep(for: .milliseconds(80))
        let second = NotchHUD(leading: AnyView(EmptyView()), trailing: AnyView(EmptyView()), announcement: "Two")
        registry.showHUD(second, for: .milliseconds(150))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(registry.hud, second, "the first one's dismissal mustn't remove the second")
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertNil(registry.hud)
        XCTAssertEqual(registry.compactWings, [])
    }
}
