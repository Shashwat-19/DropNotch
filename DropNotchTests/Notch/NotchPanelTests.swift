import XCTest
@testable import DropNotch

@MainActor
final class NotchPanelTests: XCTestCase {
    // As the window's contentView, the hosting view would resize the panel to its content (D16).
    func testHostingViewIsWrappedAndFollowsThePanelFrame() throws {
        let hosting = NotchHostingView(rootView: NotchRootView(state: NotchState()))
        let panel = NotchPanel(contentView: hosting)
        panel.setFrame(CGRect(x: 615, y: 962, width: 480, height: 150), display: false)

        let container = try XCTUnwrap(panel.contentView)
        XCTAssertFalse(container is NotchHostingView)
        XCTAssertTrue(hosting.superview === container)
        XCTAssertEqual(hosting.frame, container.bounds)
        XCTAssertEqual(hosting.frame.size, CGSize(width: 480, height: 150))
    }
}
