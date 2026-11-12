import AppKit
import Observation
import SwiftUI

/// Opens the full-screen player (D56) over the menu-bar screen when the Now Playing card's artwork is clicked, and
/// closes it on Escape, the close button, a click on the background, switching to another app, or the track going.
@MainActor
final class FullScreenPlayer {
    private let module: NowPlayingModule
    private var window: Window?
    private var generation = 0

    init(module: NowPlayingModule) {
        self.module = module
    }

    var isOpen: Bool { window?.isVisible ?? false }

    func open() {
        guard module.shown != nil, !isOpen, let screen = NSScreen.screens.first else { return }
        let window = Window(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        // Over the menu bar and the Dock; the notch panel, one level up (.statusBar), stays above it.
        window.level = .mainMenu
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.onClose = { [weak self] in self?.close() }
        window.contentView = NSHostingView(rootView: FullScreenPlayerView(module: module) { [weak self] in self?.close() })
        window.setFrame(screen.frame, display: true)
        // Key without activating DropNotch, so Escape reaches it; switching apps takes key and closes it.
        window.makeKeyAndOrderFront(nil)
        self.window = window
        generation += 1
        followTrack(generation)
    }

    func close() {
        generation += 1
        let closing = window
        window = nil
        closing?.onClose = nil
        closing?.orderOut(nil)
    }

    /// Closes when nothing is loaded any more (the player quit).
    private func followTrack(_ generation: Int) {
        guard generation == self.generation else { return }
        let empty = withObservationTracking { module.shown == nil } onChange: { [weak self] in
            Task { @MainActor in self?.followTrack(generation) }
        }
        if empty { close() }
    }

    private final class Window: NSPanel {
        var onClose: (() -> Void)?
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }

        override func cancelOperation(_ sender: Any?) { onClose?() }

        override func keyDown(with event: NSEvent) {
            // 53 is Escape, in case no responder handles cancelOperation.
            if event.keyCode == 53 { onClose?() } else { super.keyDown(with: event) }
        }

        override func resignKey() {
            super.resignKey()
            // Another app came forward (⌘Tab, a click through a notification): don't stay over it.
            onClose?()
        }
    }
}
