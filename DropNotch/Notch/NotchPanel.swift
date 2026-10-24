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
        self.contentView = contentView
    }

    // Phase 2 has no text input, so the panel never takes keyboard focus.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
