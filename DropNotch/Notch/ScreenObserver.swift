import AppKit

/// Calls `onChange` once a burst of display-configuration changes has settled
/// (200 ms one-shot debounce, ARCHITECTURE.md §9).
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

    /// The display for the single notch panel (D9): the first screen with a notch,
    /// otherwise the first screen, which `NSScreen.screens` documents as the one
    /// with the menu bar. `candidates` must be in `NSScreen.screens` order.
    nonisolated static func chooseDisplay(_ candidates: [(id: CGDirectDisplayID, hasNotch: Bool)]) -> CGDirectDisplayID? {
        (candidates.first { $0.hasNotch } ?? candidates.first)?.id
    }
}
