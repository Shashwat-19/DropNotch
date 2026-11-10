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
}
