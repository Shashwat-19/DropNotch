import AppKit

/// Borderless window that sits over the notch (ARCHITECTURE.md §6, D16).
/// Configuration only; what it shows comes from SwiftUI.
final class NotchPanel: NSPanel {
    private let canvas: NSView

    init(contentView: NSView) {
        canvas = contentView
        // `.nonactivatingPanel`: clicking the panel doesn't activate DropNotch,
        // so the app in front keeps focus.
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        // A borderless window shows no title, but VoiceOver reads it; without one the panel
        // would be an unnamed window on every Space (D21).
        title = "DropNotch"
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
        // Views don't clip by default since macOS 14, and the canvas is usually larger than the
        // panel. Clipping also limits the canvas's visibleRect, which is what keeps its
        // `.inVisibleRect` tracking area to the visible panel; don't remove it.
        container.clipsToBounds = true
        container.addSubview(contentView)
        self.contentView = container
    }

    /// Moves the panel and keeps the content canvas at `canvas`, a fixed screen rect. The
    /// canvas never moves or resizes on screen, so SwiftUI never re-lays out the shape when
    /// the panel grows: only the shape's own size animates (D19).
    func setFrame(_ frame: CGRect, canvas: CGRect) {
        // The canvas has no autoresizing mask, so this frame holds after the resize below.
        self.canvas.frame = Self.canvasFrame(panelFrame: frame, canvas: canvas)
        setFrame(frame, display: true)
    }

    /// `canvas` in the panel's own coordinates. Subtracting the snapped origins, rather than
    /// centring by half the width difference, keeps the canvas on whole pixels.
    static func canvasFrame(panelFrame: CGRect, canvas: CGRect) -> CGRect {
        canvas.offsetBy(dx: -panelFrame.minX, dy: -panelFrame.minY)
    }

    // The panel deliberately reaches 1 pt above the screen (D20). AppKit only constrains
    // titled windows, so this is a safeguard: never pull the panel back onto the screen.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    // Phase 2 has no text input, so the panel never takes keyboard focus.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
