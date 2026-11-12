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

/// The lock-screen player's window (D55): a panel that never becomes key, so it can't take a single keystroke from the
/// password field, moved into the lock-screen space the first time it shows. Clicks reach its controls without
/// activating DropNotch.
@MainActor
final class LockScreenPlayerWindow: LockScreenSurface {
    /// The card's size: the Home tab's Now Playing card with room around it. [I] Tune on device (check 137).
    nonisolated static let size = CGSize(width: 380, height: 140)
    /// Where its centre sits, as a share of the screen's height from the bottom: above the password field. [I]
    nonisolated static let heightShare: CGFloat = 0.42

    private let space: any LockScreenSpace
    private let content: () -> AnyView
    private var panel: Panel?
    private var attached = false

    init(space: any LockScreenSpace, content: @escaping () -> AnyView) {
        self.space = space
        self.content = content
    }

    var isShown: Bool { panel?.isVisible ?? false }

    func show() -> Bool {
        // The menu-bar screen: the lock screen's password field is on it [I: device check with a second display].
        guard let screen = NSScreen.screens.first else { return false }
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.setFrame(Self.frame(on: screen.frame), display: false)
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
    }

    /// Centred, `heightShare` up the screen, on whole points. Pure, for tests.
    nonisolated static func frame(on screen: CGRect) -> CGRect {
        CGRect(x: (screen.midX - size.width / 2).rounded(), y: (screen.minY + screen.height * heightShare - size.height / 2).rounded(),
               width: size.width, height: size.height)
    }

    private func makePanel() -> Panel {
        let panel = Panel(contentRect: CGRect(origin: .zero, size: Self.size), styleMask: [.borderless, .nonactivatingPanel],
                          backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        // The lock screen's own level; on its own this stays under the shield, the space puts it above (D55).
        panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.contentView = FirstClickHostingView(rootView: content())
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
