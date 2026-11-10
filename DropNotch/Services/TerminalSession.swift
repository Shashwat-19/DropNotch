import AppKit

/// One shell session in the Terminal tab (D48). A protocol, so tests never spawn a shell.
@MainActor
protocol TerminalSession: AnyObject {
    /// The terminal itself. The same view for the whole session, so closing the notch only detaches it.
    var view: NSView { get }
    /// Called once, on the main thread, when the shell exits or fails to start.
    var onExit: (() -> Void)? { get set }
    var onResize: ((_ columns: Int, _ rows: Int) -> Void)? { get set }
    /// A click in the terminal: the notch takes keyboard focus first (D31, D48).
    var onFocusRequest: (() -> Void)? { get set }
    func start(_ shell: LoginShell)
    /// Makes the terminal the first responder, once it is in a window.
    func focus()
    func apply(fontSize: CGFloat, scrollback: Int)
    /// SIGHUP now, SIGKILL after 2 s to whatever is left (End Session).
    func hangUp()
    /// SIGHUP, up to 1 s for the shell to go, then SIGKILL: before quitting, when a later kill could never run.
    func hangUpAndWait()
}
