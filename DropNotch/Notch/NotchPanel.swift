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
        let frame = Self.windowFrame(frame)
        // The canvas has no autoresizing mask, so this frame holds after the resize below.
        self.canvas.frame = Self.canvasFrame(panelFrame: frame, canvas: canvas)
        setFrame(frame, display: true)
    }

    /// AppKit rounds a window's frame to whole points, origin down and size up, even on a 2x display
    /// [V: probe, 2026-10-31: 240 frames]. A 37.5 pt panel then sat 0.5 pt lower than asked while the canvas
    /// was placed for the asked frame, leaving a pixel row of wallpaper above the shape (D29). The smallest
    /// whole-point frame around `frame` is one AppKit keeps as is, so the canvas is placed for the real frame.
    static func windowFrame(_ frame: CGRect) -> CGRect { NSIntegralRect(frame) }

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

    /// True only while the notch has keyboard focus: the hotkey, or a click asking for it (D30, D31, revises D16).
    /// Hover never makes the panel key, so typing in the app in front keeps working; the pointer leaving gives it up.
    var acceptsKeyboard = false
    /// Escape, or keyboard focus moved elsewhere (a click in another app, or `returnKeyFocus()`).
    var onDismiss: (@MainActor () -> Void)?

    override var canBecomeKey: Bool { acceptsKeyboard }
    override var canBecomeMain: Bool { false }

    /// Escape closes a hotkey-opened notch wherever focus is (D31). A text view would otherwise keep it: NSTextView
    /// takes Escape for word completion. An input method that is composing text keeps Escape to cancel that, and the
    /// terminal keeps it for its programs, as it keeps ⌘C, ⌘V and ⌘A (D48). Its other ⌘ keys are dropped here too,
    /// in case one gets past `performKeyEquivalent`: SwiftTerm's `keyDown` offers them to the app's menu.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, handle(route(event)) { return }
        super.sendEvent(event)
    }

    /// ⌘ keys reach the window here before the app's menu, so ⌘Q in the terminal can't quit DropNotch (D48).
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let route = route(event)
        return route != .dismiss && handle(route) || super.performKeyEquivalent(with: event)
    }

    private func route(_ event: NSEvent) -> NotchKeyRoute {
        NotchKeyRoute.route(keyCode: event.keyCode, characters: event.charactersIgnoringModifiers,
                            modifiers: event.modifierFlags, ownerFocused: firstResponder is NotchKeyOwner,
                            hasMarkedText: (firstResponder as? NSTextInputClient)?.hasMarkedText() == true)
    }

    /// True when the key is dealt with and AppKit shouldn't see it.
    private func handle(_ route: NotchKeyRoute) -> Bool {
        switch route {
        case .pass: return false
        case .dismiss: onDismiss?()
        case .copy: _ = firstResponder?.tryToPerform(#selector(NSText.copy(_:)), with: self)
        case .paste: _ = firstResponder?.tryToPerform(#selector(NSText.paste(_:)), with: self)
        case .selectAll: _ = firstResponder?.tryToPerform(#selector(NSResponder.selectAll(_:)), with: self)
        case .swallow: break
        }
        return true
    }

    // ⌘. lands here; Escape is caught in `sendEvent` above (D31).
    override func cancelOperation(_ sender: Any?) {
        onDismiss?()
    }

    // Overriding is fine; only calling `resignKey()` directly is discouraged.
    override func resignKey() {
        super.resignKey()
        onDismiss?()
    }

    /// Gives keyboard focus back to the app in front. The panel is non-activating, so that app stayed active
    /// the whole time; ordering the panel out makes the window server hand key focus back to its window, and
    /// ordering it straight back in keeps the closed notch on screen.
    func returnKeyFocus() {
        guard isKeyWindow else { return }
        orderOut(nil)
        orderFrontRegardless()
    }
}
