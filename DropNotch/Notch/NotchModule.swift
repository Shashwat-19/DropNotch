import SwiftUI

/// Which side of the notch a module's compact view goes on (D8).
enum CompactSlot {
    case left, right
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
    /// Whether the compact view has anything to show right now (for example, music is playing).
    var hasCompactContent: Bool { get }

    func compactView(slot: CompactSlot) -> AnyView
    func expandedView() -> AnyView
    func settingsView() -> AnyView

    /// Begin observing. Only called while the module is enabled; nothing may run before it.
    func start()
    /// Stop every observer and task. Must be safe to call twice.
    func stop()
}
