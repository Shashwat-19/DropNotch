import XCTest
@testable import DropNotch

@MainActor
final class ScreenCornersTests: XCTestCase {
    private let air = CGRect(x: 0, y: 0, width: 1470, height: 956)
    // An external display to the right, taller, so its origin isn't the main screen's.
    private let external = CGRect(x: 1470, y: -200, width: 2560, height: 1440)

    func testOnlyScreensWithANotchGetCornersAtTheirBottomEdge() {
        let frames = ScreenCorners.frames(screens: [(air, true), (external, false)], radius: 10)
        XCTAssertEqual(frames.map(\.corner), [.bottomLeft, .bottomRight])
        XCTAssertEqual(frames.map(\.frame), [CGRect(x: 0, y: 0, width: 10, height: 10),
                                             CGRect(x: 1460, y: 0, width: 10, height: 10)])
    }

    func testCornersFollowAScreenThatIsNotAtTheOrigin() {
        let frames = ScreenCorners.frames(screens: [(external, true)], radius: 12)
        XCTAssertEqual(frames.map(\.frame), [CGRect(x: 1470, y: -200, width: 12, height: 12),
                                             CGRect(x: 4018, y: -200, width: 12, height: 12)])
    }

    func testNoNotchedScreenGivesNoCorners() {
        XCTAssertTrue(ScreenCorners.frames(screens: [(external, false)]).isEmpty)
        XCTAssertTrue(ScreenCorners.frames(screens: []).isEmpty)
    }

    // The mask is black at the screen's corner and clear along the rounded edge's inside.
    func testMaskCoversTheOuterCornerOnlyOnEachSide() {
        let r: CGFloat = 10
        let left = ScreenCorners.maskPath(for: .bottomLeft, radius: r)
        XCTAssertTrue(left.contains(CGPoint(x: 0.5, y: 0.5)))
        XCTAssertFalse(left.contains(CGPoint(x: 9, y: 9)))
        XCTAssertFalse(left.contains(CGPoint(x: 9.5, y: 0.5)), "inside the disc, just above the bottom edge")
        let right = ScreenCorners.maskPath(for: .bottomRight, radius: r)
        XCTAssertTrue(right.contains(CGPoint(x: 9.5, y: 0.5)))
        XCTAssertFalse(right.contains(CGPoint(x: 1, y: 9)))
        XCTAssertFalse(right.contains(CGPoint(x: 0.5, y: 0.5)))
    }

    func testWindowLetsClicksThroughAndStaysOnEverySpace() {
        let window = ScreenCornerWindow(corner: .bottomLeft, frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        XCTAssertTrue(window.ignoresMouseEvents)
        XCTAssertFalse(window.isOpaque)
        XCTAssertFalse(window.canBecomeKey)
        XCTAssertGreaterThanOrEqual(window.level, .statusBar)
        XCTAssertTrue(window.collectionBehavior.isSuperset(of: [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]))
    }

    func testControllerShowsCornersOnlyWhileTheSettingIsOn() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "ScreenCornersTests"))
        defaults.removePersistentDomain(forName: "ScreenCornersTests")
        defer { defaults.removePersistentDomain(forName: "ScreenCornersTests") }
        let controller = ScreenCornersController(defaults: defaults)
        controller.refresh(screens: [(air, true)])
        XCTAssertTrue(controller.windows.isEmpty, "off by default (D52)")

        defaults.set(true, forKey: ScreenCorners.key)
        controller.refresh(screens: [(air, true), (external, false)])
        XCTAssertEqual(controller.windows.count, 2)
        let shown = controller.windows
        // A screen change replaces the windows rather than adding to them.
        controller.refresh(screens: [(air, true)])
        XCTAssertEqual(controller.windows.count, 2)
        XCTAssertTrue(shown.allSatisfy { !$0.isVisible })

        defaults.set(false, forKey: ScreenCorners.key)
        controller.refresh(screens: [(air, true)])
        XCTAssertTrue(controller.windows.isEmpty)
        controller.windows.forEach { $0.orderOut(nil) }
    }
}
