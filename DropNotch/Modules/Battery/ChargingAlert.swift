import AppKit
import SwiftUI

/// Shows a HUD in the closed notch when the Mac is plugged in (D52), with a haptic tap. Not a module: it has no tab or
/// card, and it runs whether or not the Battery card is on. Event-driven through `BatterySource` (D43): no timer
/// besides the HUD's own 3 s dismissal.
@MainActor
final class ChargingAlert {
    /// Settings › General › Show an alert when the Mac starts charging. On when nothing is saved.
    static let key = "chargingAlert.enabled"

    private let source: any BatterySource
    private let registry: ModuleRegistry
    private let defaults: UserDefaults
    private let haptic: @MainActor () -> Void
    private var task: Task<Void, Never>?

    /// `defaults` and `haptic` are for tests.
    init(source: any BatterySource, registry: ModuleRegistry, defaults: UserDefaults = .standard,
         haptic: @escaping @MainActor () -> Void = { Haptics.tap() }) {
        self.source = source
        self.registry = registry
        self.defaults = defaults
        self.haptic = haptic
    }

    var isEnabled: Bool { defaults.object(forKey: Self.key) as? Bool ?? true }
    var isRunning: Bool { task != nil }

    /// Plugged in since the last reading. The first reading never counts, so launching on power shows nothing; nor
    /// does a reading lost in between (nil), which would otherwise look like a fresh plug-in.
    nonisolated static func justPluggedIn(previous: BatteryStatus?, current: BatteryStatus?) -> Bool {
        guard let previous, let current else { return false }
        return !previous.isOnPower && current.isOnPower
    }

    /// Starts or stops following the battery to match the setting, so nothing observes while it's off
    /// (ARCHITECTURE.md §1 principle 4).
    func refresh() {
        if isEnabled { start() } else { stop() }
    }

    func start() {
        guard task == nil else { return }
        // Inherits the main actor. Cancelling ends the stream, which removes its run-loop source (D43).
        task = Task { [weak self, source] in
            var last: BatteryStatus?
            for await status in source.updates {
                if Self.justPluggedIn(previous: last, current: status), let status { self?.alert(status) }
                last = status
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func alert(_ status: BatteryStatus) {
        let percent = Text(Double(status.percent) / 100, format: .percent)
        let state = status.isCharging ? String(localized: "Charging") : String(localized: "On power")
        registry.showHUD(NotchHUD(
            leading: AnyView(Image(systemName: status.isCharging ? "bolt.fill" : "powerplug.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(status.isLow ? .yellow : .green)
                .frame(maxWidth: .infinity, maxHeight: .infinity)),
            trailing: AnyView(percent
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)),
            announcement: "\(state), \(status.percent.formatted(.percent))"))
        haptic()
    }
}
