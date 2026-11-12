import XCTest
@testable import DropNotch

@MainActor
final class HeadphoneAlertTests: XCTestCase {
    private final class FakeSource: HeadphoneBatterySource {
        let stream: AsyncStream<HeadphoneBattery>
        private(set) var subscriptions = 0
        init(stream: AsyncStream<HeadphoneBattery>) { self.stream = stream }
        var connections: AsyncStream<HeadphoneBattery> {
            subscriptions += 1
            return stream
        }
    }

    /// Stands in for an `IOBluetoothDevice` with the private keys (D54).
    private final class FakeDevice: NSObject {
        @objc let batteryPercentLeft = 36
        @objc let batteryPercentRight = 35
        @objc let batteryPercentCase = 0
    }

    private var suites: [String] = []

    private func makeDefaults(on: Bool? = nil) -> UserDefaults {
        let name = "HeadphoneAlertTests.\(UUID())"
        suites.append(name)
        let defaults = UserDefaults(suiteName: name)!
        if let on { defaults.set(on, forKey: HeadphoneAlert.key) }
        return defaults
    }

    override func tearDown() {
        suites.forEach { UserDefaults(suiteName: $0)?.removePersistentDomain(forName: $0) }
        suites = []
        super.tearDown()
    }

    func testZeroMeansUnknownAndTheLowerBudLeads() {
        let buds = HeadphoneBattery(left: 36, right: 35, caseLevel: 0, single: 0)
        XCTAssertEqual(buds.headline, 35)
        XCTAssertNil(buds.caseLevel)
        XCTAssertTrue(buds.hasBuds)
        XCTAssertEqual(buds.spoken, "left \(0.36.formatted(.percent)), right \(0.35.formatted(.percent))")
        let one = HeadphoneBattery(left: 0, right: nil, caseLevel: nil, single: 80)
        XCTAssertEqual(one.headline, 80)
        XCTAssertFalse(one.hasBuds)
        XCTAssertTrue(HeadphoneBattery(left: 0, right: 0, caseLevel: 0, single: 0).isEmpty)
        XCTAssertEqual(HeadphoneBattery(left: 140, right: nil, caseLevel: nil, single: nil).left, 100)
    }

    func testReadsOnlyKeysTheDeviceHas() {
        // FakeDevice has no `batteryPercentSingle`: reading it must be skipped, not raise an exception.
        let battery = IOBluetoothHeadphoneSource.read(FakeDevice())
        XCTAssertEqual(battery, HeadphoneBattery(left: 36, right: 35, caseLevel: nil, single: nil))
        XCTAssertTrue(IOBluetoothHeadphoneSource.read(NSObject()).isEmpty)
    }

    func testOffByDefaultAndSubscribesOnlyWhenOn() {
        let source = FakeSource(stream: AsyncStream { _ in })
        let defaults = makeDefaults()
        let alert = HeadphoneAlert(source: source, registry: ModuleRegistry(modules: [], defaults: makeDefaults()),
                                   defaults: defaults) {}
        XCTAssertFalse(alert.isEnabled)
        alert.refresh()
        XCTAssertEqual(source.subscriptions, 0, "no IOBluetooth access, so no Bluetooth prompt, while off (D54)")
        defaults.set(true, forKey: HeadphoneAlert.key)
        alert.refresh()
        XCTAssertTrue(alert.isRunning)
        alert.stop()
    }

    func testAConnectionShowsAHUDAndTaps() async {
        let (stream, continuation) = AsyncStream.makeStream(of: HeadphoneBattery.self)
        let registry = ModuleRegistry(modules: [], defaults: makeDefaults())
        var taps = 0
        let alert = HeadphoneAlert(source: FakeSource(stream: stream), registry: registry, defaults: makeDefaults(on: true)) {
            taps += 1
        }
        alert.refresh()
        continuation.yield(HeadphoneBattery(left: 36, right: 35, caseLevel: 80, single: nil))
        for _ in 0..<1000 where registry.hud == nil { await Task.yield() }
        XCTAssertNotNil(registry.hud)
        XCTAssertTrue(registry.hud?.announcement.hasPrefix("AirPods connected, left") ?? false)
        XCTAssertEqual(taps, 1)
        alert.stop()
    }
}
