import AppKit

/// One rounded corner (D52): a small borderless window that draws the corner's black mask and lets every click
/// through, so it never takes a click meant for the app or the Dock beneath it.
final class ScreenCornerWindow: NSWindow {
    init(corner: ScreenCorners.Corner, frame: CGRect) {
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // Clicks go to whatever is underneath (the window ignores the mouse entirely).
        ignoresMouseEvents = true
        // Above the Dock and app windows, like the notch panel (D16), so the corner stays rounded over them.
        level = .statusBar
        // Every Space and over full-screen apps; never moves with a Space switch or shows in window cycling.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView = MaskView(path: ScreenCorners.maskPath(for: corner, radius: frame.width))
    }

    /// Fills the mask in black, the colour of the bezel around the built-in display.
    private final class MaskView: NSView {
        private let path: CGPath

        init(path: CGPath) {
            self.path = path
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("Not used") }

        override func draw(_ dirtyRect: NSRect) {
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            context.setFillColor(NSColor.black.cgColor)
            context.addPath(path)
            context.fillPath()
        }
    }
}
