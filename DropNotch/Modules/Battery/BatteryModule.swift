import SwiftUI

/// The Mac's battery as a narrow Home card (D43).
@MainActor
@Observable
final class BatteryModule: NotchModule {
    let id = "battery"
    let title: LocalizedStringResource = "Battery"
    let systemImage = "battery.75percent"
    let hasCompactContent = false
    let homeCard: HomeCardSize? = .narrow
    /// Off until turned on in Settings: Home shows two cards by default (D46).
    let isEnabledByDefault = false
    /// What the source last reported; nil before the first read and while the module is off.
    private(set) var status: BatteryStatus?

    private let source: any BatterySource
    @ObservationIgnored private var task: Task<Void, Never>?

    init(source: any BatterySource) {
        self.source = source
    }

    func compactView(slot: CompactSlot) -> AnyView { AnyView(EmptyView()) }

    func expandedView() -> AnyView { AnyView(BatteryCardView(module: self)) }

    func settingsView() -> AnyView { AnyView(EmptyView()) }

    func start() {
        guard task == nil else { return }
        // Inherits the main actor. Cancelling ends the stream, which removes the run-loop source.
        task = Task { [weak self, source] in
            for await status in source.updates { self?.status = status }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        status = nil
    }
}
