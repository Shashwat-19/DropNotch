import SwiftUI

/// The black shape that extends the hardware notch (or draws a pill without one).
/// It is pinned to the top centre of the panel and sized for the displayed phase.
struct NotchRootView: View {
    let state: NotchState
    let registry: ModuleRegistry

    var body: some View {
        let size = state.geometry?.frame(for: state.displayedPhase).size ?? .zero
        let radius: CGFloat = state.displayedPhase == .open ? 18 : 10
        UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius)
            .fill(.black)
            .frame(width: size.width, height: size.height)
            // Placeholder until tabs exist: the first enabled module (D21). Only while open, so
            // a close needs no content animation (D19).
            .overlay {
                if state.displayedPhase == .open, let module = registry.expandedModules.first {
                    module.expandedView().transition(.opacity)
                }
            }
            // The panel reaches above the screen (D20); keep the shape below the screen's top.
            .padding(.top, NotchGeometry.topOverhang)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // The panel overlaps the camera housing; without this SwiftUI would push
            // the content below the screen's safe area.
            .ignoresSafeArea()
    }
}
