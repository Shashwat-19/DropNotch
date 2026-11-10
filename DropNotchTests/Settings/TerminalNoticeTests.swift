import XCTest
@testable import DropNotch

final class TerminalNoticeTests: XCTestCase {
    /// Asked the first time only (D48): Turn On Terminal records it.
    func testConfirmationIsNeededUntilRecorded() {
        let name = "TerminalNoticeTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertTrue(TerminalNotice.needsConfirmation(defaults))
        defaults.set(true, forKey: TerminalNotice.shownKey)
        XCTAssertFalse(TerminalNotice.needsConfirmation(defaults))
    }

    /// D48 names the key; changing it would ask existing users again.
    func testTheShownKey() {
        XCTAssertEqual(TerminalNotice.shownKey, "terminal.permissionsNoticeShown")
    }

    /// security-auditor L-A: a Terminal flag saved before the notice was confirmed is turned off at launch.
    @MainActor
    func testEnforceTurnsOffTerminalUntilTheNoticeIsConfirmed() {
        let name = "TerminalNoticeTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(true, forKey: "module.terminal.enabled")
        let terminal = TerminalModule(makeSession: { _, _ in fatalError("no session in this test") }, defaults: defaults)
        let registry = ModuleRegistry(modules: [terminal], defaults: defaults)
        XCTAssertTrue(registry.enabledIDs.contains("terminal"))

        TerminalNotice.enforce(on: registry, defaults: defaults)
        XCTAssertFalse(registry.enabledIDs.contains("terminal"))

        registry.setEnabled("terminal", true)
        defaults.set(true, forKey: TerminalNotice.shownKey)
        TerminalNotice.enforce(on: registry, defaults: defaults)
        XCTAssertTrue(registry.enabledIDs.contains("terminal"), "confirmed: left on")
    }
}
