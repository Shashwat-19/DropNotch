import XCTest
@testable import DropNotch

@MainActor
final class NotchPanelTests: XCTestCase {
    // Made-up notched screen with a 207 pt notch, so at 1x half the width difference to the
    // open frame is not a whole pixel.
    private func notched(inset: CGFloat, scale: CGFloat) -> NotchGeometry {
        NotchGeometry(screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: inset,
                      auxLeftWidth: 651, auxRightWidth: 654, menuBarHeight: inset, backingScale: scale)
    }

    // The bug this guards: the shape jumped to the new panel's left edge when the panel grew.
    func testCanvasKeepsTheSameScreenRectAndStaysCentredInEveryPhase() {
        for scale in [1, 2] as [CGFloat] {
            let geometry = notched(inset: 37.5, scale: scale)
            for phase in [NotchHoverStateMachine.Phase.closed, .peek, .open] {
                let panel = geometry.panelFrame(for: phase), canvas = geometry.panelFrame(for: .open)
                let local = NotchPanel.canvasFrame(panelFrame: panel, canvas: canvas)
                let label = "\(phase) at \(scale)x"
                XCTAssertEqual(local.offsetBy(dx: panel.minX, dy: panel.minY), canvas, label)
                XCTAssertEqual(local.maxY, panel.height, label)
                // Centred to within the half pixel that snapping can move an edge.
                XCTAssertEqual(local.minX, (panel.width - local.width) / 2, accuracy: 0.5 / scale, label)
                XCTAssertEqual(local.minX, (local.minX * scale).rounded() / scale, label)
            }
        }
    }

    // As the window's contentView, the hosting view would resize the panel to its content (D16).
    func testHostingViewIsWrappedAndKeepsTheCanvasSizeWhenThePanelResizes() throws {
        // Whole points: a real window snaps its frame to the pixels of whatever display the
        // test runs on; here that turned a 37.5 pt height into 38.
        let geometry = notched(inset: 38, scale: 1)
        let hosting = NotchHostingView(rootView: NotchRootView(state: NotchState()))
        let panel = NotchPanel(contentView: hosting)
        let canvas = geometry.panelFrame(for: .open)
        for phase in [NotchHoverStateMachine.Phase.peek, .open, .closed] {
            panel.setFrame(geometry.panelFrame(for: phase), canvas: canvas)
        }

        let container = try XCTUnwrap(panel.contentView)
        XCTAssertFalse(container is NotchHostingView)
        XCTAssertTrue(hosting.superview === container)
        // AppKit keeps the frame as set (D20). The made-up screen needn't match the test
        // machine's, so this doesn't prove the overhang survives above a real screen's top.
        XCTAssertEqual(panel.frame, geometry.panelFrame(for: .closed))
        XCTAssertEqual(hosting.frame, NotchPanel.canvasFrame(panelFrame: panel.frame, canvas: canvas))
        XCTAssertEqual(hosting.frame.size, canvas.size)
    }
}
