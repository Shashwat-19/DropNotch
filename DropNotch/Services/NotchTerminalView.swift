import AppKit
import SwiftTerm

/// SwiftTerm's terminal view as the notch needs it (D48): a click takes keyboard focus first, ⌘C with nothing
/// selected leaves the clipboard alone, and secure keyboard entry is on exactly while it has the keys.
final class NotchTerminalView: LocalProcessTerminalView {
    var onFocusRequest: (() -> Void)?
    private let secureInput = SecureKeyboardEntry()
    private var keyObservers: [NSObjectProtocol] = []

    // Set by SwiftTerm when the view becomes or stops being first responder.
    override var hasFocus: Bool {
        get { super.hasFocus }
        set {
            super.hasFocus = newValue
            syncSecureInput()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        keyObservers.forEach(NotificationCenter.default.removeObserver)
        keyObservers = []
        if let window {
            keyObservers = [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification].map { name in
                NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.syncSecureInput() }
                }
            }
        }
        // Off the window (the notch closed or another tab): off.
        syncSecureInput()
    }

    /// A hover-opened panel isn't key, so the first click would only make it key; this one types straight away.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onFocusRequest?()
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    /// SwiftTerm copies an empty string when nothing is selected, which would clear the clipboard.
    override func copy(_ sender: Any) {
        guard selectionActive else { return }
        super.copy(sender)
    }

    func endSecureInput() { secureInput.set(false) }

    private func syncSecureInput() {
        secureInput.set(window?.isKeyWindow == true && window?.firstResponder === self)
    }
}
