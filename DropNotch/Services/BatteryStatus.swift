import IOKit.ps

/// The Mac's internal battery, read from IOKit's power-source descriptions (D43).
struct BatteryStatus: Equatable {
    /// 0–100.
    var percent: Int
    var isCharging: Bool
    /// On the power adapter, charging or not (a full battery, or one held at a charge limit, isn't charging).
    var isOnPower: Bool

    /// Below this the ring turns the low colour (D43).
    static let lowPercent = 20
    var isLow: Bool { percent < Self.lowPercent }

    /// The first present `InternalBattery` in `descriptions` (from `IOPSGetPowerSourceDescription`); nil when there
    /// is none, as on a desktop Mac or with only a UPS attached. Pure, so tests feed it plain dictionaries.
    init?(descriptions: [[String: Any]]) {
        guard let battery = descriptions.first(where: {
            $0[kIOPSTypeKey] as? String == kIOPSInternalBatteryType && $0[kIOPSIsPresentKey] as? Bool != false
        }), let current = battery[kIOPSCurrentCapacityKey] as? Int,
              let max = battery[kIOPSMaxCapacityKey] as? Int, max > 0 else { return nil }
        // On Apple silicon these are already a percentage (max 100); the division keeps older Macs right too.
        percent = Swift.min(Swift.max(Int((Double(current) / Double(max) * 100).rounded()), 0), 100)
        isCharging = battery[kIOPSIsChargingKey] as? Bool ?? false
        isOnPower = battery[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
    }
}
