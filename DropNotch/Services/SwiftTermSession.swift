import AppKit
import Darwin
import SwiftTerm
import os

/// A shell session on SwiftTerm (D48). SwiftTerm parses output on its own I/O thread; these callbacks arrive on the
/// main thread. Nothing typed or shown is logged.
@MainActor
final class SwiftTermSession: TerminalSession {
    private let terminal: NotchTerminalView
    /// Held here: SwiftTerm keeps its delegates weakly.
    private let guardedDelegate: GuardedTerminalDelegate
    private let processEvents: ProcessEvents
    private var fontSize: CGFloat
    private var scrollback: Int
    /// Read once the shell has started: SwiftTerm's `shellPid` drops to 0 as the process is torn down.
    private var shellPid: pid_t = 0
    /// Every foreground group seen at hang-up, kept for the kill.
    private var foregroundGroups: [pid_t] = []
    private var isRunning = false
    private var hungUp = false
    private var killed = false

    var view: NSView { terminal }
    var onExit: (() -> Void)?
    var onResize: ((Int, Int) -> Void)?
    var onFocusRequest: (() -> Void)? {
        get { terminal.onFocusRequest }
        set { terminal.onFocusRequest = newValue }
    }

    init(fontSize: CGFloat, scrollback: Int) {
        self.fontSize = fontSize
        self.scrollback = scrollback
        var options = TerminalOptions.default
        // Steady: a blinking caret is a repeating animation while the notch is open (energy, D48).
        options.cursorStyle = .steadyBlock
        options.scrollback = scrollback
        terminal = NotchTerminalView(frame: .zero, font: Self.font(fontSize), options: options)
        guardedDelegate = GuardedTerminalDelegate(terminal: terminal)
        processEvents = ProcessEvents()
        // Replaces the view as its own delegate, whose clipboard methods hand programs the clipboard (OSC 52).
        terminal.terminalDelegate = guardedDelegate
        terminal.processDelegate = processEvents
        // SwiftTerm defaults to the system's text colours: a white terminal in the black notch in Light mode.
        terminal.nativeBackgroundColor = .black
        terminal.nativeForegroundColor = NSColor(white: 0.9, alpha: 1)
        // Hollow while keys go to the app in front (hover-opened), solid once it has them (design review M6).
        terminal.caretViewTracksFocus = true
        terminal.setAccessibilityLabel(String(localized: "Terminal"))
        processEvents.onExit = { [weak self] code in self?.exited(code) }
        processEvents.onResize = { [weak self] columns, rows in self?.onResize?(columns, rows) }
    }

    func start(_ shell: LoginShell) {
        guard !isRunning else { return }
        Self.markDescriptorsCloseOnExec()
        terminal.startProcess(executable: shell.executable, args: [], environment: shell.environment,
                              execName: shell.argv0, currentDirectory: shell.directory)
        // The pty master stays in DropNotch; the next session's shell mustn't inherit it (design review M1).
        let master = terminal.process.childfd
        if master >= 0 { _ = fcntl(master, F_SETFD, FD_CLOEXEC) }
        shellPid = terminal.process.shellPid
        isRunning = true
        Logger.terminal.info("Session started")
    }

    func focus() {
        terminal.window?.makeFirstResponder(terminal)
    }

    func apply(fontSize: CGFloat, scrollback: Int) {
        if fontSize != self.fontSize {
            self.fontSize = fontSize
            terminal.font = Self.font(fontSize)
        }
        if scrollback != self.scrollback {
            self.scrollback = scrollback
            terminal.changeScrollback(scrollback)
        }
    }

    func hangUp() {
        guard sendHangUp() else { return }
        // Keeps the session for 2 s, so the foreground group can be read again: a program may have started since.
        Task { [self] in
            try? await Task.sleep(for: .seconds(2))
            killRemaining()
        }
    }

    // shortcut: blocks the main thread for up to 1 s at quit or when the tab is turned off; a shell normally goes
    // at once on SIGHUP. Upgrade if a slow-exiting program makes quitting feel stuck.
    func hangUpAndWait() {
        guard shellPid > 1, !killed else { return }
        sendHangUp()
        let deadline = Date.now.addingTimeInterval(1)
        while Date.now < deadline, ([shellPid] + foregroundGroups).contains(where: { getsid($0) == shellPid }) {
            usleep(20_000)
        }
        killRemaining()
    }

    /// SIGHUP once to the shell's group and its foreground job's. False if there is no shell, or it was sent before.
    @discardableResult
    private func sendHangUp() -> Bool {
        guard shellPid > 1, !hungUp else { return false }
        hungUp = true
        terminal.endSecureInput()
        rememberForegroundGroup()
        let signalled = TerminalHangUp.send(SIGHUP, shellPid: shellPid, foregroundGroups: foregroundGroups)
        Logger.terminal.info("Session hung up: \(signalled) groups")
        return true
    }

    /// SIGKILL once to what SIGHUP left. The groups read at hang-up count too: once the shell exits its pty is gone,
    /// but a job that ignored SIGHUP is still in the shell's session (code-reviewer W1).
    private func killRemaining() {
        guard hungUp, !killed else { return }
        killed = true
        rememberForegroundGroup()
        let signalled = TerminalHangUp.send(SIGKILL, shellPid: shellPid, foregroundGroups: foregroundGroups)
        if signalled > 0 { Logger.terminal.notice("Session killed after the hang-up: \(signalled) groups") }
    }

    private func rememberForegroundGroup() {
        let master = terminal.process.childfd
        let group = master >= 0 ? tcgetpgrp(master) : -1
        if group > 1, !foregroundGroups.contains(group) { foregroundGroups.append(group) }
    }

    private func exited(_ code: Int32?) {
        guard isRunning else { return }
        isRunning = false
        terminal.endSecureInput()
        Logger.terminal.info("Session ended, status \(code.map(String.init) ?? "none", privacy: .public)")
        onExit?()
    }

    private static func font(_ size: CGFloat) -> NSFont { .monospacedSystemFont(ofSize: size, weight: .regular) }

    /// forkpty's child runs `execve` without closing DropNotch's descriptors, so every one from 3 up is marked
    /// close-on-exec first (design review M1).
    private static func markDescriptorsCloseOnExec() {
        let limit = min(getdtablesize(), 65_536)
        guard limit > 3 else { return }
        for descriptor in 3..<limit {
            let flags = fcntl(descriptor, F_GETFD)
            if flags >= 0, flags & FD_CLOEXEC == 0 { _ = fcntl(descriptor, F_SETFD, flags | FD_CLOEXEC) }
        }
    }
}

/// The view's process events: exit and size. Separate from `GuardedTerminalDelegate`, because both protocols declare
/// `hostCurrentDirectoryUpdate(source:directory:)` and the view forwards one to the other.
@MainActor
private final class ProcessEvents: LocalProcessTerminalViewDelegate {
    var onExit: ((Int32?) -> Void)?
    var onResize: ((Int, Int) -> Void)?

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) { onResize?(newCols, newRows) }
    // Titles and folders are what programs report; nothing shows or keeps them.
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    func processTerminated(source: TerminalView, exitCode: Int32?) { onExit?(exitCode) }
    func processFailedToStart(source: TerminalView, error: LocalProcessError) {
        Logger.terminal.error("Shell failed to start")
        onExit?(nil)
    }
}

/// Stands in for the view as its `terminalDelegate` (D48, design review L2): programs in the terminal can neither
/// read nor write the clipboard, and every other call goes to the view. Each method is written out; a new one that
/// SwiftTerm adds without a default fails to compile here, but one with a default wouldn't, so dependency-manager
/// checks this protocol on every SwiftTerm bump (code-reviewer S5).
@MainActor
final class GuardedTerminalDelegate: TerminalViewDelegate {
    private weak var terminal: LocalProcessTerminalView?

    init(terminal: LocalProcessTerminalView) { self.terminal = terminal }

    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        terminal?.sizeChanged(source: source, newCols: newCols, newRows: newRows)
    }
    func setTerminalTitle(source: TerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    func send(source: TerminalView, data: ArraySlice<UInt8>) { terminal?.send(source: source, data: data) }
    func scrolled(source: TerminalView, position: Double) { terminal?.scrolled(source: source, position: position) }
    /// SwiftTerm checks the link first: web links open, others ask, and runnable files are refused.
    func requestOpenLink(source: TerminalView, request: TerminalLinkRequest) {
        terminal?.requestOpenLink(source: source, request: request)
    }
    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {}
    func bell(source: TerminalView) { NSSound.beep() }
    func clipboardCopy(source: TerminalView, content: Data) {}
    func clipboardRead(source: TerminalView) -> Data? { nil }
    func kittyClipboardCapabilities(source: TerminalView) -> KittyClipboardCapabilities { [] }
    func kittyClipboardAvailableMimeTypes(source: TerminalView, location: KittyClipboardLocation) -> [String]? { nil }
    // Denied, not nil: nil would mean "use the system clipboard".
    func kittyClipboardRead(source: TerminalView, location: KittyClipboardLocation,
                            mimeType: String) -> KittyClipboardReadResult? { .denied }
    func kittyClipboardWrite(source: TerminalView, location: KittyClipboardLocation,
                             content: KittyClipboardWriteContent) -> KittyClipboardWriteResult { .denied }
    func kittyClipboardRequestPermission(source: TerminalView,
                                         request: KittyClipboardPermissionRequest) -> KittyClipboardPermissionResult { .deny }
    // iTerm's inline images and file downloads: nothing is shown or written.
    func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}
    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {
        terminal?.rangeChanged(source: source, startY: startY, endY: endY)
    }
    func programStatusChanged(source: TerminalView, records: [TerminalProgramStatus]) {}
}
