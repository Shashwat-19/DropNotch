import SwiftUI

/// The black shape that extends the hardware notch (or draws a pill without one).
/// It is pinned to the top centre of the panel and sized for the displayed phase.
struct NotchRootView: View {
    let state: NotchState
    let registry: ModuleRegistry

    var body: some View {
        // The panel's frame, not the shape's: the shape fills the 1 pt strip above the screen too, so its top
        // edge is off-screen in every state and during every animation (D29).
        let size = state.geometry?.panelFrame(for: state.displayedPhase, compact: state.displaysCompact).size ?? .zero
        let radius: CGFloat = state.displayedPhase == .open ? 18 : 10
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius)
        shape
            .fill(.black)
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .top) {
                if state.displayedPhase != .open, state.displaysCompact, let geometry = state.geometry {
                    compactSlots(geometry)
                        .padding(.top, NotchGeometry.topOverhang)
                        .transition(.opacity)
                }
            }
            // Clipped, so the wings' content never shows outside the shape while it widens or narrows (D28).
            .clipShape(shape)
            // The selected tab's module (D31). Fades in on open and vanishes at once on close, so the text
            // never pokes out of the shrinking shape (D19).
            .overlay {
                if state.displayedPhase == .open, let module = registry.selectedModule {
                    VStack(spacing: 0) {
                        // The tabs sit in the strip beside the camera housing; the module starts below it.
                        tabs.frame(height: state.geometry?.closedFrame.height ?? 0)
                        module.expandedView().frame(maxHeight: .infinity)
                    }
                    .padding(.top, NotchGeometry.topOverhang)
                    // The shape is always black, so its content uses dark colours in light mode too (L5).
                    .environment(\.colorScheme, .dark)
                    .environment(\.notchHasKeyboardFocus, state.hasKeyboardFocus)
                    // A click in a hover-opened note takes focus as the hotkey does from there (D30, D31).
                    .environment(\.requestNotchKeyboardFocus, NotchFocusRequest { state.send(.hotkeyPressed) })
                    .transition(.asymmetric(insertion: .opacity, removal: .identity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // The panel overlaps the camera housing; without this SwiftUI would push
            // the content below the screen's safe area.
            .ignoresSafeArea()
            // Escape with a control focused can stop in SwiftUI before reaching `NotchPanel.cancelOperation` (D30).
            .onExitCommand { state.send(.dismissed) }
    }

    /// One icon per module, left of the camera housing, once there is more than one module (D31).
    private var tabs: some View {
        let modules = registry.expandedModules
        return HStack(spacing: 4) {
            if modules.count > 1 {
                ForEach(Array(modules.enumerated()), id: \.element.id) { index, module in
                    tab(module, index: index)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 20)
    }

    private func tab(_ module: any NotchModule, index: Int) -> some View {
        let selected = module.id == registry.selectedModule?.id
        return Button { registry.selectedTabID = module.id } label: {
            Label { Text(module.title) } icon: { Image(systemName: module.systemImage) }
                .labelStyle(.iconOnly)
                .frame(width: 28, height: 24)
                // A filled capsule as well as brighter, so the selection doesn't rest on colour alone (L6).
                .background(Capsule().fill(.white.opacity(selected ? 0.2 : 0)))
                .foregroundStyle(selected ? .primary : .secondary)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        // ⌘1, ⌘2… while the panel is key. Not a Tab stop: Tab belongs to the module's own controls.
        .keyboardShortcut(index < 9 ? KeyboardShortcut(KeyEquivalent(Character("\(index + 1)"))) : nil)
        .focusable(false)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// The compact wings either side of the notch (D8, D28), at the closed height so peek doesn't move them.
    private func compactSlots(_ geometry: NotchGeometry) -> some View {
        HStack(spacing: 0) {
            compactSlot(.left, geometry)
            Spacer(minLength: 0)
            compactSlot(.right, geometry)
        }
        .frame(width: geometry.compactFrame.width, height: geometry.closedFrame.height)
        .environment(\.colorScheme, .dark)
    }

    private func compactSlot(_ slot: CompactSlot, _ geometry: NotchGeometry) -> some View {
        registry.slotModule(for: slot)?.compactView(slot: slot)
            // Even padding on all sides of a square wing.
            .padding(geometry.wingWidth * 0.2)
            .frame(width: geometry.wingWidth, height: geometry.closedFrame.height)
    }
}

extension EnvironmentValues {
    /// Whether the hotkey holds the notch open with keyboard focus (D30), for modules' open content.
    @Entry var notchHasKeyboardFocus = false
    /// Takes keyboard focus for a hover-opened notch (D31). Modules don't see `NotchState`.
    @Entry var requestNotchKeyboardFocus = NotchFocusRequest {}
}

/// A struct rather than a bare closure, so SwiftUI can compare it and skip redrawing the views that read it.
/// Every instance sends the same event to the one `NotchState`, so any two are equal.
struct NotchFocusRequest: Equatable {
    let action: @MainActor () -> Void
    @MainActor func callAsFunction() { action() }
    static func == (lhs: Self, rhs: Self) -> Bool { true }
}
