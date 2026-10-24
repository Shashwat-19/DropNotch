import SwiftUI

/// Hosts the SwiftUI notch content inside `NotchPanel`.
final class NotchHostingView: NSHostingView<NotchRootView> {
    required init(rootView: NotchRootView) {
        super.init(rootView: rootView)
        // NotchGeometry decides the panel's size; stop SwiftUI's content size from resizing it.
        sizingOptions = []
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("NotchHostingView is created in code only")
    }
}
