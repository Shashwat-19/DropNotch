import SwiftUI
import os

/// Hosts the SwiftUI notch content inside `NotchPanel` and reports hover to `NotchState`.
final class NotchHostingView: NSHostingView<NotchRootView> {
    private var hoverArea: NSTrackingArea?

    required init(rootView: NotchRootView) {
        super.init(rootView: rootView)
        // NotchGeometry decides the size; no Auto Layout constraints from SwiftUI's content.
        // This alone doesn't stop window resizing; NotchPanel's container does (D16), and
        // NotchPanel keeps this view at the open size (D19).
        sizingOptions = []
        // `.activeAlways`: DropNotch is never the active app, and without it the area only
        // reports while it is. `.inVisibleRect`: the area is the view's visible part, which
        // NotchPanel's clipping container limits to the panel frame, so it follows the panel
        // without recomputing in `updateTrackingAreas()` (D18).
        // `.mouseMoved`: moves inside the panel only, for the sweep guard (D20); no global monitor.
        let area = NSTrackingArea(rect: .zero,
                                  options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverArea = area
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("NotchHostingView is created in code only")
    }

    // AppKit normally spends the first click on an inactive window activating it. DropNotch is never
    // active, so without this every control would need two clicks.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

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

    // `event.trackingArea` raises for mouse-moved events, so moves can't be filtered to our
    // area. Repeats from SwiftUI's areas are expected to carry the same timestamp, and the
    // machine drops them (D20).
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        // Global x recorded with the event. Not `locationInWindow`: the panel moves when it
        // grows on entry. `mouseLocation` is "now", so it's only the fallback.
        let x = event.cgEvent?.location.x ?? NSEvent.mouseLocation.x
        rootView.state.send(.pointerMoved(x: x, time: event.timestamp))
    }

    private func logPointer(_ name: String, _ event: NSEvent) {
        let ours = event.trackingArea === hoverArea
        let pointer = NSStringFromPoint(NSEvent.mouseLocation)
        let window = NSStringFromRect(self.window?.frame ?? .zero)
        Logger.notch.debug(
            "\(name, privacy: .public) ours: \(ours), pointer \(pointer, privacy: .public), panel \(window, privacy: .public)")
    }
}
