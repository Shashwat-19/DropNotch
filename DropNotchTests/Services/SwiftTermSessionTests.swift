import Carbon
import SwiftTerm
import XCTest
@testable import DropNotch

/// What can be checked without starting a shell.
@MainActor
final class SwiftTermSessionTests: XCTestCase {
    /// Programs can neither read nor write the clipboard (D48, design review L2).
    func testTheGuardedDelegateRefusesTheClipboard() {
        let view = LocalProcessTerminalView(frame: .zero)
        let guarded = GuardedTerminalDelegate(terminal: view)
        let before = NSPasteboard.general.changeCount
        guarded.clipboardCopy(source: view, content: Data("hi".utf8))
        XCTAssertNil(guarded.clipboardRead(source: view))
        XCTAssertEqual(NSPasteboard.general.changeCount, before)
        XCTAssertEqual(guarded.kittyClipboardCapabilities(source: view), [])
        XCTAssertEqual(guarded.kittyClipboardRead(source: view, location: .standard, mimeType: "text/plain"), .denied)
    }

    /// OSC 52 written by a program, through the real parser: no clipboard change.
    func testOSC52FromOutputDoesNotTouchTheClipboard() {
        let session = SwiftTermSession(fontSize: 11, scrollback: 1_000)
        let view = session.view as! LocalProcessTerminalView
        let before = NSPasteboard.general.changeCount
        view.feed(text: "\u{1B}]52;c;aGk=\u{07}\u{1B}]52;c;?\u{07}")
        RunLoop.main.run(until: Date.now.addingTimeInterval(0.2))
        XCTAssertEqual(NSPasteboard.general.changeCount, before)
    }

    func testANewSessionIsBlackAndUnstarted() {
        let session = SwiftTermSession(fontSize: 11, scrollback: 1_000)
        let view = session.view as! LocalProcessTerminalView
        XCTAssertEqual(view.nativeBackgroundColor, .black)
        XCTAssertTrue(view.caretViewTracksFocus)
        session.hangUp()
        session.hangUpAndWait()
    }

    /// Balanced: never left on (design review L1).
    func testSecureKeyboardEntryTurnsOffAgain() {
        let secure = SecureKeyboardEntry()
        secure.set(true)
        XCTAssertTrue(IsSecureEventInputEnabled())
        secure.set(true)
        secure.set(false)
        XCTAssertFalse(IsSecureEventInputEnabled())
        secure.set(false)
        XCTAssertFalse(IsSecureEventInputEnabled())
    }

    // MARK: The view

    /// The panel can only tell the terminal is focused through `NotchKeyOwner` (D48): without it, Escape closes the
    /// notch instead of reaching the shell, ⌘C/⌘V/⌘A aren't routed, and ⌘Q reaches SwiftTerm's `keyDown`, which offers it
    /// to DropNotch's menu.
    func testTheTerminalViewIsTheKeyOwner() {
        let session = SwiftTermSession(fontSize: 11, scrollback: 1_000)
        XCTAssertTrue(session.view is NotchKeyOwner)
    }

    /// SwiftTerm copies "" with nothing selected, which would empty the clipboard (D48).
    func testCopyWithNothingSelectedLeavesTheClipboardAlone() {
        let session = SwiftTermSession(fontSize: 11, scrollback: 1_000)
        let view = session.view as! NotchTerminalView
        XCTAssertFalse(view.selectionActive)
        let before = NSPasteboard.general.changeCount
        view.copy(self)
        XCTAssertEqual(NSPasteboard.general.changeCount, before)
    }

    /// First responder in a panel that isn't key (a hover-open): secure keyboard entry stays off (D48, L1).
    func testSecureInputStaysOffInAWindowThatIsntKey() throws {
        try XCTSkipIf(IsSecureEventInputEnabled(), "another process has secure input on")
        let session = SwiftTermSession(fontSize: 11, scrollback: 1_000)
        let panel = NotchPanel(contentView: session.view)
        XCTAssertTrue(panel.makeFirstResponder(session.view))
        XCTAssertFalse(panel.isKeyWindow)
        XCTAssertFalse(IsSecureEventInputEnabled())
        session.view.removeFromSuperview()
        XCTAssertFalse(IsSecureEventInputEnabled())
    }

    // MARK: Real shells, in a scratch folder with a hand-built environment (no dotfiles, no login shell)

    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftTermSessionTests-\(UUID())")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    /// `executable` with argv0 without "-", so it isn't a login shell; HOME is the scratch folder.
    private func shell(_ executable: String, _ extra: [String] = []) -> LoginShell {
        LoginShell(executable: executable, argv0: (executable as NSString).lastPathComponent, directory: scratch.path,
                   environment: ["PATH=/usr/bin:/bin", "HOME=\(scratch.path)", "TERM=xterm-256color",
                                 "HISTFILE=/dev/null"] + extra)
    }

    /// Polls `condition`, spinning the run loop; no fixed sleep.
    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if condition() { return true }
            RunLoop.main.run(until: Date.now.addingTimeInterval(0.02))
        }
        return condition()
    }

    /// Until `pid` is gone (reaped by SwiftTerm).
    private func waitUntilGone(_ pid: pid_t) -> Bool { waitUntil { kill(pid, 0) == -1 && errno == ESRCH } }

    /// Quit and turning the tab off: the shell is gone when `hangUpAndWait()` returns (D48), and the pty master was
    /// made close-on-exec (M1).
    func testHangUpAndWaitEndsARealShell() throws {
        let session = SwiftTermSession(fontSize: 11, scrollback: 1_000)
        let view = session.view as! LocalProcessTerminalView
        session.start(shell("/bin/sh"))
        let pid = view.process.shellPid
        try XCTSkipIf(pid <= 0, "the shell didn't start")
        // forkpty's child calls setsid after the fork, so it can still be in DropNotch's session for a moment.
        XCTAssertTrue(waitUntil { getsid(pid) == pid }, "the shell leads its own session")
        XCTAssertNotEqual(getpgid(pid), getpgrp())
        let master = view.process.childfd
        XCTAssertGreaterThanOrEqual(master, 0)
        XCTAssertNotEqual(fcntl(master, F_GETFD) & FD_CLOEXEC, 0)

        session.hangUpAndWait()
        XCTAssertNotEqual(getsid(pid), pid, "no longer a running session leader when hangUpAndWait returns")
        XCTAssertTrue(waitUntilGone(pid))
        session.hangUpAndWait()
    }

    /// End Session: SIGHUP now ends a shell without waiting.
    func testHangUpEndsARealShell() throws {
        let session = SwiftTermSession(fontSize: 11, scrollback: 1_000)
        let view = session.view as! LocalProcessTerminalView
        var exits = 0
        session.onExit = { exits += 1 }
        session.start(shell("/bin/sh"))
        let pid = view.process.shellPid
        try XCTSkipIf(pid <= 0, "the shell didn't start")
        session.hangUp()
        XCTAssertTrue(waitUntilGone(pid))
        RunLoop.main.run(until: Date.now.addingTimeInterval(0.1))
        XCTAssertLessThanOrEqual(exits, 1, "onExit at most once")
    }

    /// Design review M1: a descriptor DropNotch opened without close-on-exec isn't inherited by the shell.
    func testTheShellDoesNotInheritDropNotchsDescriptors() throws {
        let null = open("/dev/null", O_RDONLY)
        XCTAssertGreaterThanOrEqual(null, 0)
        // A fixed high number, clear of the low ones the shell itself uses; F_DUPFD leaves close-on-exec off.
        let leaked = fcntl(null, F_DUPFD, 200)
        close(null)
        defer { close(leaked) }
        XCTAssertEqual(fcntl(leaked, F_GETFD) & FD_CLOEXEC, 0)

        let output = scratch.appendingPathComponent("fds.txt")
        let script = scratch.appendingPathComponent("probe.sh")
        // 0 is the pty, so it shows the check sees descriptors that are open.
        try """
        #!/bin/sh
        for n in 0 $FD; do if [ -e /dev/fd/$n ]; then echo "$n open"; else echo "$n closed"; fi; done > "$OUT"
        """.write(to: script, atomically: true, encoding: .utf8)
        XCTAssertEqual(chmod(script.path, 0o700), 0)

        let session = SwiftTermSession(fontSize: 11, scrollback: 1_000)
        let exited = expectation(description: "probe exits")
        session.onExit = { exited.fulfill() }
        session.start(shell(script.path, ["FD=\(leaked)", "OUT=\(output.path)"]))
        XCTAssertNotEqual(fcntl(leaked, F_GETFD) & FD_CLOEXEC, 0, "marked before the shell started")
        wait(for: [exited], timeout: 10)
        XCTAssertEqual(try String(contentsOf: output, encoding: .utf8), "0 open\n\(leaked) closed\n")
        session.hangUpAndWait()
    }
}
