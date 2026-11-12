import AppKit
import Observation
import SwiftUI
import os

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
        guard let shown = module.shown, !isOpen, let screen = NSScreen.screens.first else {
            Logger.nowPlaying.debug("Full screen not opened: track \(self.module.shown != nil), open \(self.isOpen)")
            return
        }
        Logger.nowPlaying.debug("Full screen opening")
        // The blurred background ready before the first frame, so the window doesn't fade in without it.
        if let artwork = shown.artwork { _ = BlurredArtwork.cached(for: artwork) }
        let window = Window(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        // Over everything, the open notch included, which would otherwise sit on the clock: only the camera cutout
        // shows, as in the screenshot Shash gave (D56).
        window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.onClose = { [weak self] in self?.close() }
        window.contentView = NSHostingView(rootView: FullScreenPlayerView(module: module) { [weak self] in self?.close() })
        window.setFrame(screen.frame, display: true)
        // The window fades, not the view: the compositor does it, with no SwiftUI redraw per frame.
        let fades = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        window.alphaValue = fades ? 0 : 1
        // Key without activating DropNotch, so Escape reaches it; switching apps takes key and closes it.
        window.makeKeyAndOrderFront(nil)
        if fades {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                window.animator().alphaValue = 1
            }
        }
        self.window = window
        generation += 1
        followTrack(generation)
    }

    func close() {
        Logger.nowPlaying.debug("Full screen closing (was open: \(self.window != nil))")
        generation += 1
        let closing = window
        window = nil
        closing?.onClose = nil
        guard let closing else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            closing.animator().alphaValue = 0
        } completionHandler: {
            closing.orderOut(nil)
        }
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
            Logger.nowPlaying.debug("Full screen resigned key")
            // Another app came forward (⌘Tab, a click through a notification): don't stay over it.
            onClose?()
        }
    }
}
