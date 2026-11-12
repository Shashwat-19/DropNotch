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

/// The lock-screen player's window (D55, D58): one panel that never becomes key, so it can't take a keystroke from the
/// password field, moved into the lock-screen space the first time it shows. Compact, it is only as big as the small
/// player, so the rest of the lock screen (clock, avatar, password prompt) is the system's; expanded, it covers the
/// screen until its × collapses it. Clicks reach its controls without activating DropNotch.
@MainActor
final class LockScreenPlayerWindow: LockScreenSurface {
    /// The compact player's size, and where its centre sits as a share of the screen's height from the top: above the
    /// avatar and password prompt [I: tuned from Shash's photo, 2026-11-13; device check 153].
    nonisolated static let compactSize = CGSize(width: 320, height: 132)
    nonisolated static let compactCentreFromTop: CGFloat = 0.66

    let presentation = LockScreenPresentation()
    private let space: any LockScreenSpace
    private let content: (LockScreenPresentation) -> AnyView
    private var panel: Panel?
    private var attached = false

    init(space: any LockScreenSpace, content: @escaping (LockScreenPresentation) -> AnyView) {
        self.space = space
        self.content = content
        presentation.onChange = { [weak self] expanded in self?.resize(expanded: expanded) }
    }

    var isShown: Bool { panel?.isVisible ?? false }

    func show() -> Bool {
        // The menu-bar screen: the lock screen's password field is on it [I: device check with a second display].
        guard let screen = NSScreen.screens.first else { return false }
        presentation.reset()
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.setFrame(Self.compactFrame(on: screen.frame), display: false)
        panel.orderFrontRegardless()
        if !attached {
            attached = space.attach(windowNumber: panel.windowNumber)
            if !attached {
                panel.orderOut(nil)
                return false
            }
        }
        return true
    }

    func hide() {
        panel?.orderOut(nil)
        presentation.reset()
    }

    private func resize(expanded: Bool) {
        guard let panel, let screen = NSScreen.screens.first else { return }
        let frame = expanded ? screen.frame : Self.compactFrame(on: screen.frame)
        // AppKit's own frame animation; none under Reduce Motion.
        panel.setFrame(frame, display: true, animate: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    /// Centred, `compactCentreFromTop` down the screen, on whole points. AppKit's y runs up. Pure, for tests.
    nonisolated static func compactFrame(on screen: CGRect) -> CGRect {
        let centreY = screen.maxY - screen.height * compactCentreFromTop
        return CGRect(x: (screen.midX - compactSize.width / 2).rounded(), y: (centreY - compactSize.height / 2).rounded(),
                      width: compactSize.width, height: compactSize.height)
    }

    private func makePanel() -> Panel {
        let panel = Panel(contentRect: CGRect(origin: .zero, size: Self.compactSize), styleMask: [.borderless, .nonactivatingPanel],
                          backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        // The lock screen's own level; on its own this stays under the shield, the space puts it above (D55).
        panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.contentView = FirstClickHostingView(rootView: content(presentation))
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
