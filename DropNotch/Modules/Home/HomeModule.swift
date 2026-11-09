import SwiftUI

/// The Home tab (D42). It holds no state and observes nothing: its cards are ordinary modules with a `homeCard`
/// size, which the registry turns on, orders, starts and stops like any other.
@MainActor
final class HomeModule: NotchModule {
    let id = "home"
    let title: LocalizedStringResource = "Home"
    let systemImage = "square.grid.2x2"
    let hasCompactContent = false

    func compactView(slot: CompactSlot) -> AnyView { AnyView(EmptyView()) }

    func expandedView() -> AnyView { AnyView(HomeView()) }

    func settingsView() -> AnyView { AnyView(EmptyView()) }

    func start() {}

    func stop() {}
}
