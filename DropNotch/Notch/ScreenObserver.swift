import AppKit

/// Calls `onChange` once a burst of display-configuration changes has settled (200 ms one-shot
/// debounce, ARCHITECTURE.md §9), and on screen sleep and wake: `onChange` closes the notch, which
/// removes its open content (D19) and so stops the progress animation and elapsed time.
@MainActor
final class ScreenObserver: NSObject {
    private let onChange: @MainActor () -> Void
    private var debounce: Task<Void, Never>?

    init(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
        super.init()
        // AppKit posts this on the main actor, so the selector runs there too.
        NotificationCenter.default.addObserver(self, selector: #selector(screenParametersChanged(_:)),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil)
        // Sleep and wake are posted on NSWorkspace's own notification centre, not the default one.
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(screenParametersChanged(_:)),
                                                              name: name, object: nil)
        }
    }

    @objc private func screenParametersChanged(_ notification: Notification) {
        debounce?.cancel()
        // A Task started here inherits the main actor, so `onChange` runs on the main thread.
        debounce = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            self?.onChange()
        }
    }

    /// The display for the single notch panel (D9): for `.builtIn`, the first screen with a notch,
    /// otherwise the first screen, which `NSScreen.screens` documents as the one
    /// with the menu bar; for `.main`, always that one (D34). `candidates` must be in `NSScreen.screens` order.
    nonisolated static func chooseDisplay(_ candidates: [(id: CGDirectDisplayID, hasNotch: Bool)],
                                          on display: NotchDisplay = .builtIn) -> CGDirectDisplayID? {
        let notched = display == .builtIn ? candidates.first { $0.hasNotch } : nil
        return (notched ?? candidates.first)?.id
    }
}
