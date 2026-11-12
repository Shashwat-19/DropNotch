import AppKit
import SwiftUI

/// What `LockScreenPlayer` shows and hides; a protocol so tests don't make windows or touch the window server.
@MainActor
protocol LockScreenSurface: AnyObject {
    /// Shows the player above the lock screen; false if it couldn't be placed there.
    func show() -> Bool
    func hide()
    var isShown: Bool { get }
}

/// The lock-screen player's windows (D55, D58): a compact one, only as big as the small player so the rest of the lock
/// screen (clock, avatar, password prompt) stays the system's, and a full-screen one for the expanded player. Both are
/// panels that never become key, so they can't take a keystroke from the password field, each moved into the
/// lock-screen space once. Expanding and collapsing swap them; neither is ever resized: resizing a window inside the
/// private space, with SwiftUI content, crashed DropNotch in a layout loop (2026-11-13 02:17).
@MainActor
final class LockScreenPlayerWindow: LockScreenSurface {
    /// The compact player's size, and where its centre sits as a share of the screen's height from the top: above the
    /// avatar and password prompt [I: tuned from Shash's photo, 2026-11-13; device check 153].
    nonisolated static let compactSize = CGSize(width: 320, height: 132)
    nonisolated static let compactCentreFromTop: CGFloat = 0.66

    let presentation = LockScreenPresentation()
    private let space: any LockScreenSpace
    private let compactContent: (LockScreenPresentation) -> AnyView
    private let expandedContent: (LockScreenPresentation) -> AnyView
    private var compact: Panel?
    private var expanded: Panel?
    private var attached: Set<Int> = []

    init(space: any LockScreenSpace, compact: @escaping (LockScreenPresentation) -> AnyView,
         expanded: @escaping (LockScreenPresentation) -> AnyView) {
        self.space = space
        compactContent = compact
        expandedContent = expanded
        presentation.onChange = { [weak self] isExpanded in self?.swap(toExpanded: isExpanded) }
    }

    var isShown: Bool { (compact?.isVisible ?? false) || (expanded?.isVisible ?? false) }

    func show() -> Bool {
        presentation.reset()
        guard let screen = NSScreen.screens.first, let panel = place(compact: true, on: screen) else { return false }
        expanded?.orderOut(nil)
        return panel.isVisible
    }

    func hide() {
        compact?.orderOut(nil)
        expanded?.orderOut(nil)
        presentation.reset()
    }

    private func swap(toExpanded isExpanded: Bool) {
        guard let screen = NSScreen.screens.first else { return }
        // The new one first, then the old one away, so the lock screen never flashes empty between them.
        guard place(compact: !isExpanded, on: screen) != nil else {
            presentation.reset()
            return
        }
        (isExpanded ? compact : expanded)?.orderOut(nil)
    }

    /// Shows the compact or expanded panel on `screen`, made and moved into the space the first time. Nil if it couldn't be
    /// placed above the lock screen.
    private func place(compact isCompact: Bool, on screen: NSScreen) -> Panel? {
        let frame = isCompact ? Self.compactFrame(on: screen.frame) : screen.frame
        let panel: Panel
        if let existing = isCompact ? compact : expanded {
            panel = existing
        } else {
            panel = makePanel(frame: frame, content: (isCompact ? compactContent : expandedContent)(presentation))
            if isCompact { compact = panel } else { expanded = panel }
        }
        // Only when the screen changed since last time (another display arrangement); otherwise the frame is left alone.
        if panel.frame != frame { panel.setFrame(frame, display: false) }
        panel.orderFrontRegardless()
        if !attached.contains(panel.windowNumber) {
            guard space.attach(windowNumber: panel.windowNumber) else {
                panel.orderOut(nil)
                return nil
            }
            attached.insert(panel.windowNumber)
        }
        return panel
    }

    /// Centred, `compactCentreFromTop` down the screen, on whole points. AppKit's y runs up. Pure, for tests.
    nonisolated static func compactFrame(on screen: CGRect) -> CGRect {
        let centreY = screen.maxY - screen.height * compactCentreFromTop
        return CGRect(x: (screen.midX - compactSize.width / 2).rounded(), y: (centreY - compactSize.height / 2).rounded(),
                      width: compactSize.width, height: compactSize.height)
    }

    private func makePanel(frame: CGRect, content: AnyView) -> Panel {
        let panel = Panel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        // The lock screen's own level; on its own this stays under the shield, the space puts it above (D55).
        panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        let hosting = FirstClickHostingView(rootView: content)
        // The window's size is ours, never the content's (as the notch, D16).
        hosting.sizingOptions = []
        panel.contentView = hosting
        return panel
    }

    /// Never key or main: the password field keeps the keyboard (D55).
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }

    /// A click on an inactive window normally only activates it; here it presses the control at once.
    private final class FirstClickHostingView: NSHostingView<AnyView> {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    }
}
