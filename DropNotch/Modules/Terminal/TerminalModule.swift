import SwiftUI
import os

/// The Terminal tab (D48): the user's login shell in SwiftTerm, off by default. The shell starts only when the tab is
/// opened on purpose (a click on the tab, its ⌘ number, ⌃⌥N, or Start Session), never on a hover-open or at launch,
/// and keeps running while the notch is closed.
@MainActor
@Observable
final class TerminalModule: NotchModule {
    let id = "terminal"
    let title: LocalizedStringResource = "Terminal"
    let systemImage = "apple.terminal"
    let hasCompactContent = false
    let isEnabledByDefault = false

    enum State: Equatable {
        case notStarted, running, ended
    }

    private(set) var state = State.notStarted
    private(set) var session: (any TerminalSession)?
    /// The shell's name for the top row, such as "zsh".
    private(set) var shellName = ""
    private(set) var columns = 0
    private(set) var rows = 0

    @ObservationIgnored private let makeSession: @MainActor (_ fontSize: CGFloat, _ scrollback: Int) -> any TerminalSession
    @ObservationIgnored private let makeShell: () -> LoginShell
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isRunning = false

    init(makeSession: @escaping @MainActor (CGFloat, Int) -> any TerminalSession,
         makeShell: @escaping () -> LoginShell = LoginShell.current, defaults: UserDefaults = .standard) {
        self.makeSession = makeSession
        self.makeShell = makeShell
        self.defaults = defaults
    }

    func compactView(slot: CompactSlot) -> AnyView { AnyView(EmptyView()) }

    func expandedView() -> AnyView { AnyView(TerminalExpandedView(module: self)) }

    func settingsView() -> AnyView { AnyView(EmptyView()) }

    func topRowAccessory() -> AnyView? { AnyView(TerminalTopRowView(module: self)) }

    /// Nothing starts here: the shell waits for the tab to be opened on purpose.
    func start() {
        isRunning = true
    }

    /// The tab turned off, or DropNotch quitting: the session and everything started in it end before this returns.
    func stop() {
        isRunning = false
        session?.hangUpAndWait()
        drop()
        state = .notStarted
    }

    /// A click on the tab or its ⌘ number. Starts the shell the first time only; after End Session it waits for Start
    /// New Session.
    func didSelectTab() {
        if state == .notStarted { openSession() }
    }

    /// Start Session, Start New Session, or ⌃⌥N on the tab.
    func openSession() {
        guard isRunning, session == nil else { return }
        let fontSize = TerminalSettings.fontSize(defaults.integer(forKey: TerminalSettings.fontSizeKey))
        let scrollback = TerminalSettings.scrollback(defaults.integer(forKey: TerminalSettings.scrollbackKey))
        let session = makeSession(fontSize, scrollback)
        session.onExit = { [weak self, weak session] in
            // A session already ended or replaced can still report its exit.
            guard let self, let session, self.session === session else { return }
            self.drop()
            self.state = .ended
        }
        session.onResize = { [weak self] columns, rows in
            self?.columns = columns
            self?.rows = rows
        }
        let shell = makeShell()
        shellName = (shell.executable as NSString).lastPathComponent
        self.session = session
        state = .running
        session.start(shell)
    }

    /// End Session: the shell and everything started in it, and its scrollback, are gone.
    func endSession() {
        guard let session else { return }
        session.hangUp()
        drop()
        state = .ended
    }

    private func drop() {
        session?.onExit = nil
        session?.onFocusRequest = nil
        session = nil
        columns = 0
        rows = 0
    }
}
