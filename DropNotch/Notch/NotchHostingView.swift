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
        // Files and file promises dropped on the notch go to the tray (D32), whether it is closed, compact or open.
        registerForDraggedTypes([.fileURL] + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
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

    // MARK: Drops (D32)

    // Mouse tracking pauses during a drag, so the drag stands in for the pointer: entering peeks and opens the notch
    // on the tray, leaving closes it. A drag from the tray itself (`draggingSource` is set only for drags inside
    // DropNotch) is refused and left out of the hover machine.

    /// The tray, when it is on.
    private var tray: FileTrayModule? {
        rootView.registry.expandedModules.lazy.compactMap { $0 as? FileTrayModule }.first
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingSource == nil, let tray else { return [] }
        rootView.registry.selectedTabID = tray.id
        rootView.state.send(.pointerEntered)
        return Self.dropOperation(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        sender.draggingSource == nil && tray != nil ? Self.dropOperation(sender) : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        guard sender?.draggingSource == nil, tray != nil else { return }
        rootView.state.send(.pointerExited)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        sender.draggingSource == nil && tray != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard sender.draggingSource == nil, let tray else { return false }
        var urls: [URL] = []
        var promises: [NSFilePromiseReceiver] = []
        // Per dragged item, the first class it offers: a real file URL before a promise, so a file is bookmarked
        // rather than copied (D6).
        sender.enumerateDraggingItems(options: [], for: self, classes: [NSURL.self, NSFilePromiseReceiver.self],
                                      searchOptions: [.urlReadingFileURLsOnly: true]) { item, _, _ in
            switch item.item {
            case let url as URL: urls.append(url)
            case let promise as NSFilePromiseReceiver: promises.append(promise)
            default: break
            }
        }
        tray.add(urls)
        tray.receive(promises)
        return !urls.isEmpty || !promises.isEmpty
    }

    /// `.copy`, else `.link`; never `.move` or `.generic`, which Finder takes as a move, so the original would leave
    /// its folder. The tray only points at the file either way.
    static func dropOperation(_ info: NSDraggingInfo) -> NSDragOperation {
        let mask = info.draggingSourceOperationMask
        return mask.contains(.copy) ? .copy : mask.intersection(.link)
    }

    private func logPointer(_ name: String, _ event: NSEvent) {
        let ours = event.trackingArea === hoverArea
        let pointer = NSStringFromPoint(NSEvent.mouseLocation)
        let window = NSStringFromRect(self.window?.frame ?? .zero)
        Logger.notch.debug(
            "\(name, privacy: .public) ours: \(ours), pointer \(pointer, privacy: .public), panel \(window, privacy: .public)")
    }
}
