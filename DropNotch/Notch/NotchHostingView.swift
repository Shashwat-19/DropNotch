import SwiftUI

/// Hosts the SwiftUI notch content inside `NotchPanel` and reports hover to `NotchState`.
final class NotchHostingView: NSHostingView<NotchRootView> {
    private var hoverArea: NSTrackingArea?

    required init(rootView: NotchRootView) {
        super.init(rootView: rootView)
        // NotchGeometry decides the panel's size; stop SwiftUI's content size from resizing it.
        sizingOptions = []
        // `.activeAlways`: DropNotch is never the active app, and without it the area only
        // reports while it is. `.inVisibleRect`: the area follows the view as the panel
        // resizes, so it never needs recomputing in `updateTrackingAreas()` (D18).
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverArea = area
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("NotchHostingView is created in code only")
    }

    // SwiftUI's own hover tracking also calls these, so only our area's events are forwarded.
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if event.trackingArea === hoverArea { rootView.state.send(.pointerEntered) }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if event.trackingArea === hoverArea { rootView.state.send(.pointerExited) }
    }
}
