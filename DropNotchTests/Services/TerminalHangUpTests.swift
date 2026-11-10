import XCTest
@testable import DropNotch

final class TerminalHangUpTests: XCTestCase {
    private func targets(_ shell: pid_t, _ foreground: pid_t, ownGroup: pid_t = 500, ownPid: pid_t = 501) -> [pid_t] {
        TerminalHangUp.targets(shellPid: shell, foregroundGroup: foreground, ownGroup: ownGroup, ownPid: ownPid)
    }

    func testTheShellAndItsForegroundJob() {
        XCTAssertEqual(targets(900, 950), [900, 950])
        XCTAssertEqual(targets(900, 900), [900], "each once")
    }

    /// killpg(0) is DropNotch's own group; kill(-1) reaches every process the user owns (design review M3).
    func testNeverZeroOneNegativeOrDropNotchItself() {
        for shell: pid_t in [0, 1, -1] { XCTAssertEqual(targets(shell, 950), [], "shell \(shell)") }
        XCTAssertEqual(targets(900, -1), [900], "tcgetpgrp failed")
        XCTAssertEqual(targets(900, 0), [900])
        XCTAssertEqual(targets(900, 1), [900])
        XCTAssertEqual(targets(900, 500), [900], "our own group")
        XCTAssertEqual(targets(900, 501), [900], "our own pid")
        XCTAssertEqual(targets(500, 950), [950], "a shell pid equal to our group")
    }

    /// The real call refuses a group outside the shell's session: here DropNotch's own (the test host's).
    func testSendSkipsGroupsOutsideTheShellsSession() {
        XCTAssertEqual(TerminalHangUp.send(0, shellPid: getpid(), foregroundGroup: getpgrp()), 0)
        XCTAssertEqual(TerminalHangUp.send(0, shellPid: 99_999, foregroundGroup: -1), 0, "no such process")
    }

    // MARK: Real processes, each spawned here and only ever signalled here

    private var spawned: [pid_t] = []

    override func tearDown() {
        // Only our own children: SIGKILL whatever is left, then reap.
        for pid in spawned where waitpid(pid, nil, WNOHANG) == 0 {
            kill(pid, SIGKILL)
            waitpid(pid, nil, 0)
        }
        spawned = []
        super.tearDown()
    }

    /// `/bin/sleep 30` with the given posix_spawn flags.
    private func spawnSleep(flags: Int32) throws -> pid_t {
        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        posix_spawnattr_setflags(&attributes, Int16(flags))
        let argv: [UnsafeMutablePointer<CChar>?] = [strdup("/bin/sleep"), strdup("30"), nil]
        defer { argv.forEach { free($0) } }
        let env: [UnsafeMutablePointer<CChar>?] = [nil]
        var pid: pid_t = 0
        let status = posix_spawn(&pid, "/bin/sleep", nil, &attributes, argv, env)
        try XCTSkipIf(status != 0, "posix_spawn failed: \(status)")
        spawned.append(pid)
        return pid
    }

    /// The signal that ended `pid`, after reaping it; nil if it exited normally.
    private func terminatingSignal(_ pid: pid_t) -> Int32? {
        var status: Int32 = 0
        XCTAssertEqual(waitpid(pid, &status, 0), pid)
        let signal = status & 0x7f
        return signal == 0 ? nil : signal
    }

    /// A session leader stands in for the shell (forkpty calls setsid): SIGHUP reaches its group and ends it.
    func testSendHangsUpAShellInItsOwnSession() throws {
        let shell = try spawnSleep(flags: Int32(POSIX_SPAWN_SETSID))
        XCTAssertEqual(getsid(shell), shell)
        XCTAssertEqual(TerminalHangUp.send(SIGHUP, shellPid: shell, foregroundGroup: -1), 1)
        XCTAssertEqual(terminatingSignal(shell), SIGHUP)
    }

    /// A foreground group that isn't in the shell's session (a reused pid, say) is left alone (design review M3).
    func testSendSkipsARealGroupOutsideTheShellsSession() throws {
        let shell = try spawnSleep(flags: Int32(POSIX_SPAWN_SETSID))
        // Its own process group, but in the test host's session.
        let outsider = try spawnSleep(flags: Int32(POSIX_SPAWN_SETPGROUP))
        XCTAssertEqual(getpgid(outsider), outsider)
        XCTAssertNotEqual(getsid(outsider), shell)
        XCTAssertEqual(TerminalHangUp.send(SIGHUP, shellPid: shell, foregroundGroup: outsider), 1)
        XCTAssertEqual(terminatingSignal(shell), SIGHUP)
        XCTAssertEqual(waitpid(outsider, nil, WNOHANG), 0, "still running")
        XCTAssertEqual(kill(outsider, 0), 0)
    }
}
