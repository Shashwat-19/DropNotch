import SwiftUI
import os

/// Hosts the SwiftUI notch content inside `NotchPanel` and reports hover to `NotchState`.
final class NotchHostingView: NSHostingView<NotchRootView> {
    private var hoverArea: NSTrackingArea?

    required init(rootView: NotchRootView) {
        super.init(rootView: rootView)
        // NotchGeometry decides the size; no Auto Layout constraints from SwiftUI's content.
        // This alone doesn't stop window resizing; NotchPanel's container does (D16).
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
        logPointer("mouseEntered", event)
        if event.trackingArea === hoverArea { rootView.state.send(.pointerEntered) }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        logPointer("mouseExited", event)
        if event.trackingArea === hoverArea { rootView.state.send(.pointerExited) }
    }

    private func logPointer(_ name: String, _ event: NSEvent) {
        let ours = event.trackingArea === hoverArea
        let pointer = NSStringFromPoint(NSEvent.mouseLocation)
        let window = NSStringFromRect(self.window?.frame ?? .zero)
        Logger.notch.debug(
            "\(name, privacy: .public) ours: \(ours), pointer \(pointer, privacy: .public), panel \(window, privacy: .public)")
    }
}
