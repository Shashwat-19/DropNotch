import SwiftUI

/// The black shape that extends the hardware notch (or draws a pill without one).
/// It is pinned to the top centre of the panel and sized for the displayed phase.
struct NotchRootView: View {
    let state: NotchState

    var body: some View {
        let size = state.geometry?.frame(for: state.displayedPhase).size ?? .zero
        let radius: CGFloat = state.displayedPhase == .open ? 18 : 10
        UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius)
            .fill(.black)
            .frame(width: size.width, height: size.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // The panel overlaps the camera housing; without this SwiftUI would push
            // the content below the screen's safe area.
            .ignoresSafeArea()
    }
}
