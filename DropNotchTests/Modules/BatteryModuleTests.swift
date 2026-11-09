import IOKit.ps
import XCTest
@testable import DropNotch

@MainActor
final class BatteryModuleTests: XCTestCase {
    private final class FakeSource: BatterySource {
        var stream: AsyncStream<BatteryStatus?>
        private(set) var subscriptions = 0

        init(stream: AsyncStream<BatteryStatus?>) { self.stream = stream }

        var updates: AsyncStream<BatteryStatus?> {
            subscriptions += 1
            return stream
        }
    }

    /// A status at `percent` (BatteryStatus has no memberwise init, so it goes through the IOKit parser).
    private func status(_ percent: Int, charging: Bool = false) -> BatteryStatus? {
        BatteryStatus(descriptions: [[kIOPSTypeKey: kIOPSInternalBatteryType, kIOPSCurrentCapacityKey: percent,
                                      kIOPSMaxCapacityKey: 100, kIOPSIsChargingKey: charging]])
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<1000 where !condition() { await Task.yield() }
    }

    func testIsANarrowHomeCardWithoutCompactContent() {
        let module = BatteryModule(source: FakeSource(stream: AsyncStream { _ in }))
        XCTAssertEqual(module.id, "battery")
        XCTAssertEqual(module.homeCard, .narrow)
        XCTAssertFalse(module.hasCompactContent)
        XCTAssertNil(module.status)
    }

    /// Home shows two cards until Battery is turned on (D46).
    func testIsOffByDefault() {
        XCTAssertFalse(BatteryModule(source: FakeSource(stream: AsyncStream { _ in })).isEnabledByDefault)
    }

    func testStartShowsFirstStatusAndFollowsLaterOnes() async {
        let (stream, continuation) = AsyncStream.makeStream(of: BatteryStatus?.self)
        let module = BatteryModule(source: FakeSource(stream: stream))
        module.start()
        continuation.yield(status(60))
        await waitUntil { module.status != nil }
        XCTAssertEqual(module.status, status(60))
        continuation.yield(status(61, charging: true))
        await waitUntil { module.status?.percent != 60 }
        XCTAssertEqual(module.status, status(61, charging: true))
    }

    func testNilFromSourceClearsStatus() async {
        let (stream, continuation) = AsyncStream.makeStream(of: BatteryStatus?.self)
        let module = BatteryModule(source: FakeSource(stream: stream))
        module.start()
        continuation.yield(status(60))
        await waitUntil { module.status != nil }
        continuation.yield(nil)
        await waitUntil { module.status == nil }
        XCTAssertNil(module.status)
    }

    func testStartTwiceSubscribesOnce() async {
        let (stream, continuation) = AsyncStream.makeStream(of: BatteryStatus?.self)
        let source = FakeSource(stream: stream)
        let module = BatteryModule(source: source)
        module.start()
        module.start()
        continuation.yield(status(50))
        await waitUntil { module.status != nil }
        for _ in 0..<50 { await Task.yield() }
        XCTAssertEqual(source.subscriptions, 1)
    }

    // Cancelling the consuming task terminates the stream, which is observable without any sleeping.
    func testStopClearsStatusAndEndsTheStream() async {
        let (stream, continuation) = AsyncStream.makeStream(of: BatteryStatus?.self)
        let ended = expectation(description: "stream ended")
        continuation.onTermination = { _ in ended.fulfill() }
        let module = BatteryModule(source: FakeSource(stream: stream))
        module.start()
        continuation.yield(status(40))
        await waitUntil { module.status != nil }
        module.stop()
        XCTAssertNil(module.status)
        await fulfillment(of: [ended], timeout: 5)
        continuation.yield(status(41))
        for _ in 0..<50 { await Task.yield() }
        XCTAssertNil(module.status)
        module.stop()
        XCTAssertNil(module.status)
    }

    func testStartAfterStopSubscribesAgain() async {
        let (first, firstContinuation) = AsyncStream.makeStream(of: BatteryStatus?.self)
        let source = FakeSource(stream: first)
        let module = BatteryModule(source: source)
        module.start()
        firstContinuation.yield(status(30))
        await waitUntil { module.status != nil }
        module.stop()

        // The cancelled consumer ended the old stream, so the source hands out a fresh one, as the real one does.
        let (second, secondContinuation) = AsyncStream.makeStream(of: BatteryStatus?.self)
        source.stream = second
        module.start()
        secondContinuation.yield(status(90))
        await waitUntil { module.status != nil }
        XCTAssertEqual(module.status, status(90))
        XCTAssertEqual(source.subscriptions, 2)
    }
}
