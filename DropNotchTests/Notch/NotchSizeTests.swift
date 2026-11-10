import SwiftUI
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
        let state = NotchState(defaults: defaults)
        state.setNotchSize(.large)
        XCTAssertEqual(state.notchSize, .large)
        XCTAssertEqual(defaults.string(forKey: NotchSize.key), "large")
        XCTAssertNil(state.geometry)
    }

    // MARK: Gaps (test-writer)

    private let air = CGRect(x: 0, y: 0, width: 1470, height: 956)

    private func notched(left: CGFloat = 631, right: CGFloat = 631, inset: CGFloat = 32, scale: CGFloat = 2,
                         items: Int = 5, size: NotchSize) -> NotchGeometry {
        NotchGeometry(screenFrame: air, safeAreaTop: inset, auxLeftWidth: left, auxRightWidth: right,
                      menuBarHeight: inset, backingScale: scale, topRowItems: items, size: size)
    }

    private func pill(size: NotchSize) -> NotchGeometry {
        NotchGeometry(screenFrame: air, safeAreaTop: 0, auxLeftWidth: nil, auxRightWidth: nil, menuBarHeight: 24,
                      backingScale: 2, size: size)
    }

    /// Without a notch, Large is the 480 pt minimum plus 80, 230 pt tall, centred on the screen; the pill is unchanged.
    func testLargePillWithoutANotch() {
        let standard = pill(size: .standard), large = pill(size: .large)
        XCTAssertFalse(large.hasNotch)
        XCTAssertEqual(large.openFrame.size, CGSize(width: 560, height: 230))
        XCTAssertEqual(large.openFrame.midX, air.midX)
        XCTAssertEqual(large.openFrame.maxY, air.maxY)
        XCTAssertEqual(large.closedFrame, standard.closedFrame)
        XCTAssertEqual(large.openTopRowLeading, large.openFrame.width / 2)
    }

    /// A housing far wider than the default: whatever wins at Standard, Large adds 80 pt on top of it.
    func testLargeOnAWideNotchAddsItsWidthToWhateverWins() {
        let standard = notched(left: 100, right: 100, size: .standard)
        let large = notched(left: 100, right: 100, size: .large)
        XCTAssertEqual(standard.openFrame.width, 1598, "housing 1270 + 2 × 164 pt top row")
        XCTAssertEqual(large.openFrame.size, CGSize(width: 1678, height: 230))
        XCTAssertTrue(large.openFrame.contains(large.compactPeekFrame))
        XCTAssertGreaterThanOrEqual(large.openFrame.width - large.openTopRowLeading, NotchGeometry.topRowWidth())
    }

    /// The open panel stays the canvas at Large (D19): every phase's body and panel, with any wings, fits inside it,
    /// and its edges land on whole device pixels even under a fractional inset.
    func testLargeOpenPanelIsTheCanvasForEveryPhase() {
        let wingSets: [Set<CompactSlot>] = [[], [.left], [.right], [.left, .right]]
        for geometry in [notched(items: 6, size: .large), notched(inset: 33.5, scale: 1, size: .large),
                         notched(inset: 33.5, scale: 2, size: .large), notched(left: 100, right: 100, size: .large),
                         pill(size: .large)] {
            let canvas = geometry.panelFrame(for: .open)
            for phase in [NotchHoverStateMachine.Phase.closed, .peek, .open] {
                for wings in wingSets {
                    XCTAssertTrue(canvas.contains(geometry.frame(for: phase, wings: wings)), "\(phase) \(wings)")
                    XCTAssertTrue(canvas.contains(geometry.panelFrame(for: phase, wings: wings)), "panel \(phase) \(wings)")
                }
            }
        }
        for scale: CGFloat in [1, 2] {
            let open = notched(inset: 33.5, scale: scale, size: .large).openFrame
            for edge in [open.minX, open.maxX, open.minY, open.maxY] {
                XCTAssertEqual((edge * scale).rounded(), edge * scale, "\(open) at \(scale)x")
            }
        }
    }

    /// At Large the header is 16 + 36 pt plus the 4 pt gap, and each row 16 pt with 2 pt between: n rows need exactly
    /// 54 + 18n pt, and half a point less gives one fewer. Never below one row.
    func testCalendarCapacityStepsAtLarge() {
        for rows in 1...8 {
            let height = CGFloat(54 + 18 * rows)
            XCTAssertEqual(CalendarCardView.capacity(height: height, size: .large), rows, "height \(height)")
            if rows > 1 {
                XCTAssertEqual(CalendarCardView.capacity(height: height - 0.5, size: .large), rows - 1,
                               "height \(height - 0.5)")
            }
        }
        XCTAssertEqual(CalendarCardView.capacity(height: 71.5, size: .large), 1, "less than one row still shows one")
        XCTAssertEqual(CalendarCardView.capacity(height: 0, size: .large), 1)
    }

    /// Standard keeps the system text styles (D49); Large swaps each for a fixed size one step up.
    func testNotchFontIsTheSystemStyleAtStandard() {
        XCTAssertEqual(Font.notch(.subheadline, .standard), .subheadline)
        XCTAssertEqual(Font.notch(.body, .standard), .body)
        XCTAssertEqual(Font.notch(.title3, .standard), .title3)
        XCTAssertEqual(Font.notch(.title2, .standard), .title2)
        XCTAssertEqual(Font.notch(.subheadline, .large), .system(size: 13))
        XCTAssertEqual(Font.notch(.body, .large), .system(size: 15))
        XCTAssertEqual(Font.notch(.title3, .large), .system(size: 17))
        XCTAssertEqual(Font.notch(.title2, .large), .system(size: 20))
    }

    /// Picking the size already in use writes nothing. Uses whatever size the state started with, so it doesn't
    /// depend on the real defaults domain.
    @MainActor
    func testSetNotchSizeToTheCurrentSizeSavesNothing() {
        let name = "NotchSizeTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let state = NotchState(defaults: defaults)
        let current = state.notchSize
        state.setNotchSize(current)
        XCTAssertEqual(state.notchSize, current)
        XCTAssertNil(defaults.string(forKey: NotchSize.key))
        XCTAssertNil(state.geometry)
    }
}
