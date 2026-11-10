import XCTest
@testable import DropNotch

@MainActor
final class TerminalModuleTests: XCTestCase {
    /// Stands in for SwiftTerm: no shell is ever spawned.
    private final class FakeSession: TerminalSession {
        let view = NSView()
        var onExit: (() -> Void)?
        var onResize: ((Int, Int) -> Void)?
        var onFocusRequest: (() -> Void)?
        private(set) var started: [LoginShell] = []
        private(set) var hangUps = 0
        private(set) var waitedHangUps = 0
        private(set) var applied: [(CGFloat, Int)] = []
        func start(_ shell: LoginShell) { started.append(shell) }
        func focus() {}
        func apply(fontSize: CGFloat, scrollback: Int) { applied.append((fontSize, scrollback)) }
        func hangUp() { hangUps += 1 }
        func hangUpAndWait() { waitedHangUps += 1 }
    }

    private var made: [(session: FakeSession, fontSize: CGFloat, scrollback: Int)] = []
    private var suites: [String] = []
    private let shell = LoginShell(executable: "/bin/zsh", argv0: "-zsh", directory: "/Users/you", environment: [])

    override func tearDown() {
        suites.forEach { UserDefaults(suiteName: $0)?.removePersistentDomain(forName: $0) }
        super.tearDown()
    }

    private func makeDefaults() -> UserDefaults {
        let name = "TerminalModuleTests.\(UUID())"
        suites.append(name)
        return UserDefaults(suiteName: name)!
    }

    private func module(defaults: UserDefaults? = nil, start: Bool = true) -> TerminalModule {
        let module = TerminalModule(makeSession: { [unowned self] fontSize, scrollback in
            let session = FakeSession()
            made.append((session, fontSize, scrollback))
            return session
        }, makeShell: { [shell] in shell }, defaults: defaults ?? makeDefaults())
        if start { module.start() }
        return module
    }

    func testOffByDefaultWithAnAccessory() {
        let module = module(start: false)
        XCTAssertEqual(module.id, "terminal")
        XCTAssertFalse(module.isEnabledByDefault)
        XCTAssertNotNil(module.topRowAccessory())
        XCTAssertNil(module.homeCard)
    }

    /// Nothing at launch or on a hover-open: only an explicit open starts a shell (D48, design review M4).
    func testStartSpawnsNothing() {
        let module = module()
        XCTAssertEqual(module.state, .notStarted)
        XCTAssertTrue(made.isEmpty)
    }

    func testSelectingTheTabStartsTheShellOnce() {
        let module = module()
        module.didSelectTab()
        module.didSelectTab()
        module.openSession()
        XCTAssertEqual(made.count, 1)
        XCTAssertEqual(made[0].session.started, [shell])
        XCTAssertEqual(module.state, .running)
        XCTAssertEqual(module.shellName, "zsh")
    }

    func testNothingStartsWhileStopped() {
        let module = module(start: false)
        module.didSelectTab()
        module.openSession()
        XCTAssertTrue(made.isEmpty)
    }

    func testEndSessionHangsUpAndOnlyStartNewSessionStartsAgain() {
        let module = module()
        module.didSelectTab()
        let first = made[0].session
        module.endSession()
        XCTAssertEqual(first.hangUps, 1)
        XCTAssertEqual(module.state, .ended)
        XCTAssertNil(module.session)
        module.didSelectTab()
        XCTAssertEqual(made.count, 1, "a tab click doesn't restart an ended session")
        module.openSession()
        XCTAssertEqual(made.count, 2)
        XCTAssertEqual(module.state, .running)
    }

    func testTheShellExitingEndsTheSessionAndALateExitIsIgnored() {
        let module = module()
        module.didSelectTab()
        let first = made[0].session
        first.onExit?()
        XCTAssertEqual(module.state, .ended)
        module.openSession()
        let second = made[1].session
        first.onExit?()
        XCTAssertEqual(module.state, .running, "the old session's exit mustn't end the new one")
        XCTAssertTrue(module.session === second)
    }

    func testStopEndsTheSessionAndWaitsAndIsSafeTwice() {
        let module = module()
        module.didSelectTab()
        let session = made[0].session
        module.stop()
        module.stop()
        XCTAssertEqual(session.waitedHangUps, 1)
        XCTAssertEqual(module.state, .notStarted)
        XCTAssertNil(module.session)
        module.start()
        module.didSelectTab()
        XCTAssertEqual(made.count, 2, "turned on again, a tab click starts a new shell")
    }

    func testResizeIsReportedAndClearedWithTheSession() {
        let module = module()
        module.didSelectTab()
        made[0].session.onResize?(80, 11)
        XCTAssertEqual(module.columns, 80)
        XCTAssertEqual(module.rows, 11)
        module.endSession()
        XCTAssertEqual(module.columns, 0)
    }

    func testTheSessionGetsTheSettingsOrTheirDefaults() {
        let defaults = makeDefaults()
        defaults.set(13, forKey: TerminalSettings.fontSizeKey)
        defaults.set(5_000, forKey: TerminalSettings.scrollbackKey)
        let module = module(defaults: defaults)
        module.didSelectTab()
        XCTAssertEqual(made[0].fontSize, 13)
        XCTAssertEqual(made[0].scrollback, 5_000)

        defaults.set(40, forKey: TerminalSettings.fontSizeKey)
        defaults.set(7, forKey: TerminalSettings.scrollbackKey)
        module.endSession()
        module.openSession()
        XCTAssertEqual(made[1].fontSize, 11)
        XCTAssertEqual(made[1].scrollback, 1_000)
    }

    func testSettingsFallBackOutsideTheirRange() {
        XCTAssertEqual(TerminalSettings.fontSize(0), 11, "unset")
        XCTAssertEqual(TerminalSettings.fontSize(9), 11)
        XCTAssertEqual(TerminalSettings.fontSize(10), 10)
        XCTAssertEqual(TerminalSettings.fontSize(14), 14)
        XCTAssertEqual(TerminalSettings.fontSize(15), 11)
        XCTAssertEqual(TerminalSettings.scrollback(0), 1_000)
        XCTAssertEqual(TerminalSettings.scrollback(10_000), 10_000)
        XCTAssertEqual(TerminalSettings.scrollback(2_000), 1_000)
    }

    func testEndSessionAndStopWithoutASessionDoNothing() {
        let module = module()
        module.endSession()
        XCTAssertEqual(module.state, .notStarted, "End Session before any session doesn't mark it ended")
        module.stop()
        XCTAssertEqual(module.state, .notStarted)
        XCTAssertTrue(made.isEmpty)
    }

    /// An ended session's callbacks are cut, so a late exit or click can't reach the module (or a later session).
    func testEndingASessionDetachesItsCallbacks() {
        let module = module()
        module.didSelectTab()
        let first = made[0].session
        first.onFocusRequest = {}
        module.endSession()
        XCTAssertNil(first.onExit)
        XCTAssertNil(first.onFocusRequest)
        module.openSession()
        module.stop()
        XCTAssertNil(made[1].session.onExit)
        XCTAssertEqual(made[1].session.hangUps, 0, "stop waits instead")
        XCTAssertEqual(made[1].session.waitedHangUps, 1)
    }

    /// The top row names the shell actually started, such as the fallback when the account's isn't usable.
    func testShellNameFollowsTheShellStarted() {
        let fish = LoginShell(executable: "/opt/homebrew/bin/fish", argv0: "-fish", directory: "/Users/you", environment: [])
        let module = TerminalModule(makeSession: { _, _ in FakeSession() }, makeShell: { fish }, defaults: makeDefaults())
        module.start()
        module.didSelectTab()
        XCTAssertEqual(module.shellName, "fish")
    }
}
