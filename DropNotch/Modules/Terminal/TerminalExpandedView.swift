import AppKit
import SwiftUI

/// The terminal in the open notch (D48): before a session, Start Session; while one runs, the session's own view; once
/// it has ended, Start New Session.
struct TerminalExpandedView: View {
    let module: TerminalModule
    @Environment(\.notchHasKeyboardFocus) private var hasKeyboardFocus
    @Environment(\.requestNotchKeyboardFocus) private var requestKeyboardFocus
    @AppStorage(TerminalSettings.fontSizeKey) private var fontSize = TerminalSettings.defaultFontSize
    @AppStorage(TerminalSettings.scrollbackKey) private var scrollback = TerminalSettings.defaultScrollback
    @FocusState private var focus: Focus?

    var body: some View {
        content
            // ⌃⌥N on this tab opens it on purpose: the shell starts (D48).
            .onChange(of: hasKeyboardFocus, initial: true) {
                guard hasKeyboardFocus else { return }
                if module.state == .notStarted { module.openSession() }
                focusStartButton()
            }
            // After End Session or an exit with the keys here, Start New Session takes them (code-reviewer S7).
            .onChange(of: module.state) { if hasKeyboardFocus { focusStartButton() } }
    }

    /// Only while a button is showing: a running terminal takes the keys itself, and moving SwiftUI's focus then would
    /// take first responder from it (code-reviewer S3).
    private func focusStartButton() {
        if module.state != .running { focus = .start }
    }

    @ViewBuilder
    private var content: some View {
        switch module.state {
        case .notStarted:
            NotchEmptyState("Your login shell, in your home folder", systemImage: "apple.terminal") {
                Button("Start Session", action: module.openSession)
                    .keyboardControl(Focus.start, focus: $focus, action: module.openSession)
            }
        case .running:
            if let session = module.session {
                TerminalHost(session: session, hasKeyboardFocus: hasKeyboardFocus, requestFocus: requestKeyboardFocus,
                             fontSize: TerminalSettings.fontSize(fontSize),
                             scrollback: TerminalSettings.scrollback(scrollback))
            }
        case .ended:
            NotchEmptyState("Session ended", systemImage: "apple.terminal") {
                Button("Start New Session", action: module.openSession)
                    .keyboardControl(Focus.start, focus: $focus, action: module.openSession)
            }
        }
    }

    private enum Focus: Hashable {
        case start
    }
}

/// Hosts the session's view in a plain container, so the same view moves between hosts as the notch opens and closes.
private struct TerminalHost: NSViewRepresentable {
    let session: any TerminalSession
    let hasKeyboardFocus: Bool
    let requestFocus: NotchFocusRequest
    let fontSize: CGFloat
    let scrollback: Int

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        attach(to: container)
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        attach(to: container)
        session.apply(fontSize: fontSize, scrollback: scrollback)
        // A click in the terminal takes keyboard focus for a hover-opened notch, as a click in a note does (D31).
        session.onFocusRequest = { requestFocus() }
        if hasKeyboardFocus {
            // The view may join the window only after this update.
            DispatchQueue.main.async { [session] in session.focus() }
        }
    }

    static func dismantleNSView(_ container: NSView, coordinator: ()) {
        container.subviews.forEach { $0.removeFromSuperview() }
    }

    private func attach(to container: NSView) {
        let view = session.view
        guard view.superview !== container else { return }
        view.removeFromSuperview()
        view.frame = container.bounds
        view.autoresizingMask = [.width, .height]
        container.addSubview(view)
    }
}
