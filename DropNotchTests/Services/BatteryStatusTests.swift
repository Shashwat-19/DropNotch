import IOKit.ps
import XCTest
@testable import DropNotch

final class BatteryStatusTests: XCTestCase {
    /// One power-source description keyed like `IOPSGetPowerSourceDescription`'s; nil values are left out.
    private func source(type: String = kIOPSInternalBatteryType, present: Bool? = true, current: Int? = 50,
                        max: Int? = 100, charging: Bool = false, state: String = kIOPSBatteryPowerValue) -> [String: Any] {
        var description: [String: Any] = [kIOPSTypeKey: type, kIOPSIsChargingKey: charging,
                                          kIOPSPowerSourceStateKey: state]
        if let present { description[kIOPSIsPresentKey] = present }
        if let current { description[kIOPSCurrentCapacityKey] = current }
        if let max { description[kIOPSMaxCapacityKey] = max }
        return description
    }

    func testInternalBatteryOnBatteryPower() {
        let status = BatteryStatus(descriptions: [source(current: 73)])
        XCTAssertEqual(status?.percent, 73)
        XCTAssertEqual(status?.isCharging, false)
        XCTAssertEqual(status?.isOnPower, false)
    }

    func testChargingOnAC() {
        let status = BatteryStatus(descriptions: [source(charging: true, state: kIOPSACPowerValue)])
        XCTAssertEqual(status?.isCharging, true)
        XCTAssertEqual(status?.isOnPower, true)
    }

    // A full battery, or one held at a charge limit, is on power but not charging.
    func testOnACNotCharging() {
        let status = BatteryStatus(descriptions: [source(current: 80, charging: false, state: kIOPSACPowerValue)])
        XCTAssertEqual(status?.percent, 80)
        XCTAssertEqual(status?.isCharging, false)
        XCTAssertEqual(status?.isOnPower, true)
    }

    // IOKit hands back CFNumber/CFBoolean values, not Swift ones.
    func testReadsBridgedFoundationValues() {
        let description: [String: Any] = [
            kIOPSTypeKey: kIOPSInternalBatteryType as NSString, kIOPSIsPresentKey: kCFBooleanTrue as Any,
            kIOPSCurrentCapacityKey: NSNumber(value: 42), kIOPSMaxCapacityKey: NSNumber(value: 100),
            kIOPSIsChargingKey: kCFBooleanTrue as Any, kIOPSPowerSourceStateKey: kIOPSACPowerValue as NSString,
        ]
        let status = BatteryStatus(descriptions: [description])
        XCTAssertEqual(status?.percent, 42)
        XCTAssertEqual(status?.isCharging, true)
        XCTAssertEqual(status?.isOnPower, true)
    }

    func testUPSOnlyIsNil() {
        XCTAssertNil(BatteryStatus(descriptions: [source(type: kIOPSUPSType)]))
    }

    func testEmptyIsNil() {
        XCTAssertNil(BatteryStatus(descriptions: []))
    }

    func testBatteryNotPresentIsNil() {
        XCTAssertNil(BatteryStatus(descriptions: [source(present: false)]))
    }

    func testMissingIsPresentCountsAsPresent() {
        XCTAssertEqual(BatteryStatus(descriptions: [source(present: nil, current: 30)])?.percent, 30)
    }

    func testUPSListedFirstPicksTheInternalBattery() {
        let status = BatteryStatus(descriptions: [source(type: kIOPSUPSType, current: 10, state: kIOPSACPowerValue),
                                                  source(current: 90)])
        XCTAssertEqual(status?.percent, 90)
        XCTAssertEqual(status?.isOnPower, false)
    }

    func testMissingCurrentCapacityIsNil() {
        XCTAssertNil(BatteryStatus(descriptions: [source(current: nil)]))
    }

    func testMissingMaxCapacityIsNil() {
        XCTAssertNil(BatteryStatus(descriptions: [source(max: nil)]))
    }

    func testZeroMaxCapacityIsNil() {
        XCTAssertNil(BatteryStatus(descriptions: [source(current: 0, max: 0)]))
    }

    func testCapacityNotOutOfHundredIsScaled() {
        XCTAssertEqual(BatteryStatus(descriptions: [source(current: 4000, max: 5000)])?.percent, 80)
    }

    func testPercentIsRounded() {
        XCTAssertEqual(BatteryStatus(descriptions: [source(current: 2, max: 3)])?.percent, 67)
        XCTAssertEqual(BatteryStatus(descriptions: [source(current: 1, max: 3)])?.percent, 33)
        XCTAssertEqual(BatteryStatus(descriptions: [source(current: 1, max: 200)])?.percent, 1) // 0.5 rounds up
    }

    func testPercentIsClampedToZeroThroughHundred() {
        XCTAssertEqual(BatteryStatus(descriptions: [source(current: 120, max: 100)])?.percent, 100)
        XCTAssertEqual(BatteryStatus(descriptions: [source(current: -5, max: 100)])?.percent, 0)
    }

    func testIsLowBelowTwenty() {
        XCTAssertEqual(BatteryStatus(descriptions: [source(current: 19)])?.isLow, true)
        XCTAssertEqual(BatteryStatus(descriptions: [source(current: 20)])?.isLow, false)
        XCTAssertEqual(BatteryStatus.lowPercent, 20)
    }
}
