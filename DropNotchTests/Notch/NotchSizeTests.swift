import XCTest
@testable import DropNotch

final class NotchSizeTests: XCTestCase {
    /// The Air-like screen of NotchGeometryTests: 1470 × 956 pt, a 208 pt housing 32 pt tall.
    private func geometry(items: Int, size: NotchSize) -> NotchGeometry {
        NotchGeometry(screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956), safeAreaTop: 32, auxLeftWidth: 631,
                      auxRightWidth: 631, menuBarHeight: 32, backingScale: 2, topRowItems: items, size: size)
    }

    /// Shash's pick (D49): 676 × 230 with six top-row items, 616 × 230 with five or fewer; Standard unchanged.
    func testOpenSizesOnTheAir() {
        XCTAssertEqual(geometry(items: 6, size: .standard).openFrame.size, CGSize(width: 596, height: 190))
        XCTAssertEqual(geometry(items: 5, size: .standard).openFrame.size, CGSize(width: 536, height: 190))
        XCTAssertEqual(geometry(items: 6, size: .large).openFrame.size, CGSize(width: 676, height: 230))
        XCTAssertEqual(geometry(items: 5, size: .large).openFrame.size, CGSize(width: 616, height: 230))
        XCTAssertEqual(geometry(items: 2, size: .large).openFrame.size, CGSize(width: 616, height: 230))
    }

    /// The closed and peek shapes don't change with the size; only the open one does.
    func testOnlyTheOpenShapeChanges() {
        let standard = geometry(items: 6, size: .standard), large = geometry(items: 6, size: .large)
        XCTAssertEqual(standard.closedFrame, large.closedFrame)
        XCTAssertEqual(standard.peekFrame, large.peekFrame)
        XCTAssertEqual(standard.compactFrame, large.compactFrame)
        XCTAssertEqual(standard.openFrame.midX, large.openFrame.midX, "still centred on the notch")
        XCTAssertEqual(standard.openFrame.maxY, large.openFrame.maxY, "still hangs from the top")
        XCTAssertGreaterThanOrEqual(large.openFrame.width - large.openTopRowLeading, NotchGeometry.topRowWidth(items: 6))
    }

    func testScaledIsOneTextStepUp() {
        XCTAssertEqual(NotchSize.standard.scaled(28), 28)
        XCTAssertEqual(NotchSize.large.scaled(28), 32)
        XCTAssertEqual(NotchSize.large.scaled(24), 28)
        XCTAssertEqual(NotchSize.large.scaled(14), 16)
        XCTAssertEqual(NotchSize.large.scaled(72), 83)
    }

    func testSavedDefaultsToStandard() {
        let name = "NotchSizeTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertEqual(NotchSize.saved(defaults), .standard)
        defaults.set("huge", forKey: NotchSize.key)
        XCTAssertEqual(NotchSize.saved(defaults), .standard)
        defaults.set("large", forKey: NotchSize.key)
        XCTAssertEqual(NotchSize.saved(defaults), .large)
    }

    /// Calendar rows on Home's card (D46, D49): 5 on the Air's 126 pt card at Standard, 6 on its 166 pt card at Large.
    func testCalendarRowsFollowTheSize() {
        XCTAssertEqual(CalendarCardView.capacity(height: 126, size: .standard), 5)
        XCTAssertEqual(CalendarCardView.capacity(height: 166, size: .large), 6)
        XCTAssertEqual(CalendarCardView.capacity(height: 126, size: .large), 4, "larger rows on a Standard card")
    }

    /// Before the first screen read, a switch is only saved (no panel work).
    @MainActor
    func testSetNotchSizeSavesItBeforeAnyScreen() {
        let name = "NotchSizeTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let state = NotchState()
        state.setNotchSize(.large, defaults: defaults)
        XCTAssertEqual(state.notchSize, .large)
        XCTAssertEqual(defaults.string(forKey: NotchSize.key), "large")
        XCTAssertNil(state.geometry)
    }
}
