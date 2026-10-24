import XCTest
@testable import DropNotch

// ScreenObserver is @MainActor, so its static helper is too.
@MainActor
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
}
