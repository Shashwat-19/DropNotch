/// Battery levels of connected headphones (D54). Each figure is 1–100, or nil when unknown: IOBluetooth reports 0 for
/// a closed case or a value it doesn't have.
struct HeadphoneBattery: Equatable, Sendable {
    var left: Int?
    var right: Int?
    var caseLevel: Int?
    /// Headphones with one battery (not AirPods-style buds).
    var single: Int?

    init(left: Int?, right: Int?, caseLevel: Int?, single: Int?) {
        self.left = Self.level(left)
        self.right = Self.level(right)
        self.caseLevel = Self.level(caseLevel)
        self.single = Self.level(single)
    }

    private static func level(_ raw: Int?) -> Int? {
        guard let raw, raw > 0 else { return nil }
        return min(raw, 100)
    }

    var hasBuds: Bool { left != nil || right != nil }
    var isEmpty: Bool { !hasBuds && single == nil && caseLevel == nil }
    /// The figure the HUD shows: the lower bud, since that one runs out first; else the single battery.
    var headline: Int? { [left, right].compactMap { $0 }.min() ?? single }

    /// For VoiceOver: every figure that's known.
    var spoken: String {
        func percent(_ value: Int) -> String { (Double(value) / 100).formatted(.percent) }
        var parts: [String] = []
        if let left { parts.append(String(localized: "left \(percent(left))")) }
        if let right { parts.append(String(localized: "right \(percent(right))")) }
        if let caseLevel { parts.append(String(localized: "case \(percent(caseLevel))")) }
        if let single, !hasBuds { parts.append(percent(single)) }
        return parts.joined(separator: ", ")
    }
}

/// Where the headphone HUD gets readings (D54). `@MainActor`: its only consumer is `HeadphoneAlert`.
@MainActor
protocol HeadphoneBatterySource {
    /// One reading per headphone connection made after subscribing; not polled. Iterate it once.
    var connections: AsyncStream<HeadphoneBattery> { get }
}
