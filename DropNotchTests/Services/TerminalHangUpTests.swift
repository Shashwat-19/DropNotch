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
}
