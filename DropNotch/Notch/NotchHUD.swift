import SwiftUI

/// A timed peek in the closed notch (ARCHITECTURE.md §3, "Transient HUDs"; D52): for a few seconds the closed shape
/// widens to both wings and shows `leading` and `trailing` there instead of the compact slots' modules. Anything can
/// ask for one through `ModuleRegistry.showHUD`; the charging alert is the first.
struct NotchHUD: Equatable {
    let id = UUID()
    let leading: AnyView
    let trailing: AnyView
    /// What VoiceOver says when it appears, since the wings aren't focusable.
    let announcement: String

    /// How long one stays, unless another replaces it (ARCHITECTURE.md §9, "Peek dismissal").
    static let duration: Duration = .seconds(3)

    /// Equal only to itself, so showing the same content twice restarts it.
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}
