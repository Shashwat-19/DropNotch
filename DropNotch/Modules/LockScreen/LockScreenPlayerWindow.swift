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

/// The lock-screen player's window (D55, D57): the full-screen player across the whole screen, in a panel that never
/// becomes key, so it can't take a single keystroke from the password field, moved into the lock-screen space the
/// first time it shows. Clicks reach its controls without activating DropNotch; its clear bottom lets clicks through
/// to the password field [I: device check 149].
@MainActor
final class LockScreenPlayerWindow: LockScreenSurface {
    /// The share of the screen it covers, from the top. The rest stays the system's: the avatar and password field sit
    /// in the lower part of the lock screen, and covering the whole screen hid them (Shash, 2026-11-13).
    nonisolated static let coverage: CGFloat = 0.70
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

    /// The top `coverage` of the screen (AppKit's y runs up, so the window starts above the bottom 30 %). Pure, for tests.
    nonisolated static func frame(on screen: CGRect) -> CGRect {
        let height = (screen.height * coverage).rounded()
        return CGRect(x: screen.minX, y: screen.maxY - height, width: screen.width, height: height)
    }

    private func makePanel() -> Panel {
        let panel = Panel(contentRect: Self.frame(on: NSScreen.screens.first?.frame ?? .zero),
                          styleMask: [.borderless, .nonactivatingPanel],
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
