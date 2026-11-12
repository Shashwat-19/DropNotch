import SwiftUI

/// Shows a HUD with the headphones' battery when they connect (D54). Like `ChargingAlert`: not a module, off unless
/// turned on, and nothing observed while off, so the Bluetooth permission prompt only follows the user's choice.
@MainActor
final class HeadphoneAlert {
    /// Settings › General › Show headphone battery when they connect. Off when nothing is saved (D54).
    static let key = "headphoneAlert.enabled"

    private let source: any HeadphoneBatterySource
    private let registry: ModuleRegistry
    private let defaults: UserDefaults
    private let haptic: @MainActor () -> Void
    private var task: Task<Void, Never>?

    init(source: any HeadphoneBatterySource, registry: ModuleRegistry, defaults: UserDefaults = .standard,
         haptic: @escaping @MainActor () -> Void = { Haptics.tap() }) {
        self.source = source
        self.registry = registry
        self.defaults = defaults
        self.haptic = haptic
    }

    var isEnabled: Bool { defaults.bool(forKey: Self.key) }
    var isRunning: Bool { task != nil }

    func refresh() {
        if isEnabled { start() } else { stop() }
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self, source] in
            for await battery in source.connections { self?.alert(battery) }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func alert(_ battery: HeadphoneBattery) {
        guard let headline = battery.headline else { return }
        let name = battery.hasBuds ? String(localized: "AirPods") : String(localized: "Headphones")
        registry.showHUD(NotchHUD(
            leading: AnyView(Image(systemName: battery.hasBuds ? "airpods" : "headphones")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)),
            trailing: AnyView(Text(Double(headline) / 100, format: .percent)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(headline < BatteryStatus.lowPercent ? .yellow : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)),
            announcement: String(localized: "\(name) connected, \(battery.spoken)")))
        haptic()
    }
}
