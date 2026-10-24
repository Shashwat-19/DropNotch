import SwiftUI

/// The black shape that extends the hardware notch (or draws a pill without one).
struct NotchRootView: View {
    var body: some View {
        UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10)
            .fill(.black)
            // The panel overlaps the camera housing; without this SwiftUI would push
            // the content below the screen's safe area.
            .ignoresSafeArea()
    }
}
