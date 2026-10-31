import SwiftUI

/// The black shape that extends the hardware notch (or draws a pill without one).
/// It is pinned to the top centre of the panel and sized for the displayed phase.
struct NotchRootView: View {
    let state: NotchState
    let registry: ModuleRegistry

    var body: some View {
        let size = state.geometry?.frame(for: state.displayedPhase, compact: state.displaysCompact).size ?? .zero
        let radius: CGFloat = state.displayedPhase == .open ? 18 : 10
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius)
        shape
            .fill(.black)
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .top) {
                if state.displayedPhase != .open, state.displaysCompact, let geometry = state.geometry {
                    compactSlots(geometry)
                        .transition(.opacity)
                }
            }
            // Clipped, so the wings' content never shows outside the shape while it widens or narrows (D28).
            .clipShape(shape)
            // Placeholder until tabs exist: the first enabled module (D21). Fades in on open and
            // vanishes at once on close, so the text never pokes out of the shrinking shape (D19).
            .overlay {
                if state.displayedPhase == .open, let module = registry.expandedModules.first {
                    module.expandedView()
                        // Start below the closed notch, so nothing sits under the camera housing.
                        .padding(.top, state.geometry?.closedFrame.height ?? 0)
                        // The shape is always black, so its content uses dark colours in light mode too (L5).
                        .environment(\.colorScheme, .dark)
                        .transition(.asymmetric(insertion: .opacity, removal: .identity))
                }
            }
            // The panel reaches above the screen (D20); keep the shape below the screen's top.
            .padding(.top, NotchGeometry.topOverhang)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // The panel overlaps the camera housing; without this SwiftUI would push
            // the content below the screen's safe area.
            .ignoresSafeArea()
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
