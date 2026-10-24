import AppKit

/// Borderless window that sits over the notch (ARCHITECTURE.md §6, D16).
/// Configuration only; what it shows comes from SwiftUI.
final class NotchPanel: NSPanel {
    init(contentView: NSView) {
        // `.nonactivatingPanel`: clicking the panel doesn't activate DropNotch,
        // so the app in front keeps focus.
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        // NSPanel hides itself when its app is inactive by default, and DropNotch is
        // almost never the active app.
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        // One level above the menu bar's, so the panel draws over it.
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        // An NSHostingView that is a window's contentView resizes the window to fit its
        // SwiftUI content, even with `sizingOptions = []`. Wrapping it in a plain view
        // keeps the frame under NotchGeometry's control (D16).
        let container = NSView()
        // Autoresizing only adds size changes, so start from the container's bounds.
        contentView.frame = container.bounds
        contentView.autoresizingMask = [.width, .height]
        container.addSubview(contentView)
        self.contentView = container
    }

    // Phase 2 has no text input, so the panel never takes keyboard focus.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
