import SwiftUI

/// Which side of the notch a module's compact view goes on (D8).
enum CompactSlot {
    case left, right
}

/// How much of the Home tab's row a card takes (D42): a wide card takes what the others leave.
enum HomeCardSize {
    case wide, medium, narrow

    /// Share of the row's width; nil for wide. Medium is 40 % so the Calendar card's titles fit beside Now Playing
    /// (D46, docs/mockups/home-layout-v0.2.html); narrow is from the first mock-up (D42).
    var share: CGFloat? {
        switch self {
        case .wide: nil
        case .medium: 0.4
        case .narrow: 0.215
        }
    }
}

/// One feature of the notch (ARCHITECTURE.md §3, D21). `ModuleRegistry` owns the instances,
/// decides when `start()` and `stop()` run, and keeps the enabled flag.
///
/// Swift notes:
/// - `@MainActor`: the compiler guarantees these are only used on the main thread.
/// - `AnyObject`: only classes can conform, so the registry and the module share one
///   instance. A struct would be copied and `stop()` would act on the wrong copy.
/// - `AnyView`: lets modules with different view types sit in one array.
@MainActor
protocol NotchModule: AnyObject {
    /// Stable key for layout and settings storage. Lowercase with hyphens.
    var id: String { get }
    var title: LocalizedStringResource { get }
    /// SF Symbol for the module's tab in the open notch (D31).
    var systemImage: String { get }
    /// Whether the module has a compact view at all, so Settings offers it for a compact slot (D8).
    var hasCompactView: Bool { get }
    /// Whether the compact view has anything to show right now (for example, music is playing).
    var hasCompactContent: Bool { get }
    /// Non-nil: the module's `expandedView()` is a card on the Home tab, and it has no tab of its own (D42).
    var homeCard: HomeCardSize? { get }
    /// Whether the module is on before the user has set it either way (D46). A saved setting always wins.
    var isEnabledByDefault: Bool { get }

    func compactView(slot: CompactSlot) -> AnyView
    func expandedView() -> AnyView
    func settingsView() -> AnyView
    /// Shown in the open notch's top row left of the camera housing while the module's tab is selected (D48).
    func topRowAccessory() -> AnyView?
    /// Its tab was clicked or chosen with its ⌘ number: opened on purpose, unlike a hover-open (D48).
    func didSelectTab()
    /// Choosing its tab (a click or its ⌘ number) also gives the notch keyboard focus, so it can be typed into at once
    /// without a second click (D48: the terminal).
    var takesKeysOnSelect: Bool { get }

    /// Begin observing. Only called while the module is enabled; nothing may run before it.
    func start()
    /// Stop every observer and task. Must be safe to call twice.
    func stop()
}

extension NotchModule {
    var hasCompactView: Bool { false }
    var homeCard: HomeCardSize? { nil }
    var isEnabledByDefault: Bool { true }
    func topRowAccessory() -> AnyView? { nil }
    func didSelectTab() {}
    var takesKeysOnSelect: Bool { false }
}
