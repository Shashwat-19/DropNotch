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

    // MARK: Settings › General › "Show the notch on" (D34)

    func testMainAlwaysPicksTheMenuBarScreenEvenWhenALaterOneHasANotch() {
        XCTAssertEqual(ScreenObserver.chooseDisplay([(id: 1, hasNotch: false), (id: 2, hasNotch: true)], on: .main), 1)
        XCTAssertEqual(ScreenObserver.chooseDisplay([(id: 3, hasNotch: true), (id: 4, hasNotch: false)], on: .main), 3)
        XCTAssertNil(ScreenObserver.chooseDisplay([], on: .main))
    }

    func testBuiltInExplicitlyMatchesTheDefault() {
        let candidates: [(id: CGDirectDisplayID, hasNotch: Bool)] = [(id: 1, hasNotch: false), (id: 2, hasNotch: true)]
        XCTAssertEqual(ScreenObserver.chooseDisplay(candidates, on: .builtIn), 2)
        XCTAssertEqual(ScreenObserver.chooseDisplay([(id: 5, hasNotch: false), (id: 6, hasNotch: false)], on: .builtIn), 5)
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

    // Sleep closes the notch through the same path, so the progress animation and elapsed time stop.
    @MainActor
    func testScreenSleepAndWakeCallOnChange() async throws {
        var calls = 0
        let observer = ScreenObserver { calls += 1 }
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.screensDidSleepNotification, object: nil)
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(calls, 1)
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.screensDidWakeNotification, object: nil)
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(calls, 2)
        withExtendedLifetime(observer) {}
    }
}

