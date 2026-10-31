import AppKit
import SwiftUI

/// Clicks and drags on a tray item (D32). AppKit, not SwiftUI's `onDrag`, because only an `NSDraggingSource`
/// decides the operation: `.copy` alone, so Finder copies the file instead of moving the original, and the Trash
/// (which needs `.delete` or `.move`) refuses it.
struct TrayItemDragSource: NSViewRepresentable {
    let urls: () -> [URL]
    let onClick: (_ extending: Bool) -> Void

    func makeNSView(context: Context) -> TrayItemDragView { TrayItemDragView() }

    func updateNSView(_ view: TrayItemDragView, context: Context) {
        view.urls = urls
        view.onClick = onClick
    }
}

final class TrayItemDragView: NSView, NSDraggingSource {
    var urls: () -> [URL] = { [] }
    var onClick: (_ extending: Bool) -> Void = { _ in }
    private var pendingMouseDown: NSEvent?

    override init(frame: NSRect) {
        super.init(frame: frame)
        // The SwiftUI tile carries the label and actions for VoiceOver.
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("TrayItemDragView is created in code only")
    }

    // One click works in the never-active panel, as in NotchHostingView.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) { pendingMouseDown = event }

    override func mouseDragged(with event: NSEvent) {
        guard let down = pendingMouseDown else { return }
        // A few points of movement first, so a slightly wobbly click still selects.
        let dx = event.locationInWindow.x - down.locationInWindow.x, dy = event.locationInWindow.y - down.locationInWindow.y
        guard dx * dx + dy * dy > 9 else { return }
        pendingMouseDown = nil
        let items = urls().map { url in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            item.setDraggingFrame(bounds, contents: NSWorkspace.shared.icon(forFile: url.path))
            return item
        }
        guard !items.isEmpty else { return }
        beginDraggingSession(with: items, event: down, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        if pendingMouseDown != nil { onClick(event.modifierFlags.contains(.command)) }
        pendingMouseDown = nil
    }

    // Nothing inside DropNotch takes it; the notch never drops its own items back in (NotchHostingView).
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? .copy : []
    }
}
