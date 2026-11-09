import XCTest
@testable import DropNotch

/// The real IOKit subscription (D43). Works with or without a battery, so CI Macs can run it.
@MainActor
final class PowerSourceBatterySourceTests: XCTestCase {
    func testFirstReadingArrivesAtOnce() async {
        var iterator = PowerSourceBatterySource().updates.makeAsyncIterator()
        let first = await iterator.next()
        // An element arrived: a status on a laptop, nil on a desktop Mac.
        XCTAssertNotNil(first)
        if !PowerSourceBatterySource.hasInternalBattery { XCTAssertNil(first ?? nil) }
    }

    /// Subscribing and cancelling again and again adds and removes the run-loop source each time without crashing,
    /// as turning the card off and on in Settings does.
    func testRepeatedSubscribeAndCancelTearsDown() async {
        for _ in 0..<20 {
            let task = Task { for await _ in PowerSourceBatterySource().updates {} }
            await Task.yield()
            task.cancel()
            await task.value
        }
        // Lets the main-queue teardown blocks run.
        await Task.yield()
    }
}
