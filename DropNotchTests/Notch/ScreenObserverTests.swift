import XCTest
@testable import DropNotch

final class ScreenObserverTests: XCTestCase {
    func testNotchedDisplayWinsEvenWhenNotFirst() {
        XCTAssertEqual(ScreenObserver.chooseDisplay([(id: 1, hasNotch: false), (id: 2, hasNotch: true)]), 2)
    }

    func testFirstNotchedDisplayWinsWhenSeveralHaveNotches() {
        XCTAssertEqual(ScreenObserver.chooseDisplay([(id: 1, hasNotch: false), (id: 2, hasNotch: true),
                                                     (id: 3, hasNotch: true)]), 2)
    }

    func testWithoutANotchTheMenuBarScreenWins() {
        XCTAssertEqual(ScreenObserver.chooseDisplay([(id: 5, hasNotch: false), (id: 6, hasNotch: false)]), 5)
    }

    func testNoDisplaysGivesNil() {
        XCTAssertNil(ScreenObserver.chooseDisplay([]))
    }

    @MainActor
    func testBurstOfScreenChangesCallsOnChangeOnce() async throws {
        var calls = 0
        let observer = ScreenObserver { calls += 1 }
        // The test host's own AppDelegate also repositions its panel on these; that's harmless.
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(calls, 1)
        withExtendedLifetime(observer) {}
    }
}
