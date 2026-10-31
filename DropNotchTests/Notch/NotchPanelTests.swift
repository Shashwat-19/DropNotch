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
        let hosting = NotchHostingView(rootView: NotchRootView(state: NotchState(), registry: ModuleRegistry(modules: [])))
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

    // The bug this guards (D29): AppKit rounded a 37.5 pt panel down by 0.5 pt while the canvas was placed
    // for the asked frame, so a pixel row of wallpaper showed above the shape. `appKit` is the rounding the
    // probe measured: origin down, size up.
    func testShapeTopIsAtOrAboveTheScreenTopInEveryState() {
        let appKit = { (r: CGRect) in
            CGRect(x: r.minX.rounded(.down), y: r.minY.rounded(.down),
                   width: r.width.rounded(.up), height: r.height.rounded(.up))
        }
        let screens: [(name: String, frame: CGRect, inset: CGFloat, left: CGFloat?, right: CGFloat?, menuBar: CGFloat)] = [
            ("notch 37.5", CGRect(x: 0, y: 0, width: 1512, height: 982), 37.5, 651, 654, 37.5),
            ("notch 32", CGRect(x: -1512, y: 0, width: 1512, height: 982), 32, 650.25, 653, 32),
            ("pill 24.5", CGRect(x: 1512, y: -200, width: 1920, height: 1080), 0, nil, nil, 24.5),
        ]
        for screen in screens {
            for scale in [1, 2] as [CGFloat] {
                let geometry = NotchGeometry(screenFrame: screen.frame, safeAreaTop: screen.inset,
                                             auxLeftWidth: screen.left, auxRightWidth: screen.right,
                                             menuBarHeight: screen.menuBar, backingScale: scale)
                let canvas = geometry.panelFrame(for: .open)
                for phase in [NotchHoverStateMachine.Phase.closed, .peek, .open] {
                    for compact in [false, true] {
                        let label = "\(screen.name) \(phase) compact \(compact) at \(scale)x"
                        let window = NotchPanel.windowFrame(geometry.panelFrame(for: phase, compact: compact))
                        XCTAssertEqual(appKit(window), window, "AppKit would move the window: \(label)")
                        let local = NotchPanel.canvasFrame(panelFrame: window, canvas: canvas)
                        let onScreen = local.offsetBy(dx: appKit(window).minX, dy: appKit(window).minY)
                        // NotchRootView pins the shape to the canvas top at the panel frame's height.
                        let shapeTop = onScreen.maxY
                        let shapeBottom = shapeTop - geometry.panelFrame(for: phase, compact: compact).height
                        XCTAssertGreaterThanOrEqual(shapeTop, screen.frame.maxY, label)
                        XCTAssertEqual(shapeBottom, geometry.frame(for: phase, compact: compact).minY, label)
                    }
                }
            }
        }
    }

    // A real window: whatever display the test runs on, AppKit keeps the whole-point frame as set.
    func testRealPanelKeepsTheWholePointFrameForAFractionalNotch() {
        let geometry = notched(inset: 37.5, scale: 2)
        let panel = NotchPanel(contentView: NSView())
        for phase in [NotchHoverStateMachine.Phase.closed, .peek, .open] {
            for compact in [false, true] {
                let asked = geometry.panelFrame(for: phase, compact: compact)
                panel.setFrame(asked, canvas: geometry.panelFrame(for: .open))
                XCTAssertEqual(panel.frame, NotchPanel.windowFrame(asked), "\(phase) compact \(compact)")
                XCTAssertTrue(panel.frame.contains(asked))
            }
        }
    }

    // Hover never makes the panel key; only the hotkey does (D30).
    func testPanelBecomesKeyOnlyWhenAcceptingKeyboardAndEscapeDismisses() {
        let panel = NotchPanel(contentView: NSView())
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
        panel.acceptsKeyboard = true
        XCTAssertTrue(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)

        var dismissals = 0
        panel.onDismiss = { dismissals += 1 }
        panel.cancelOperation(nil)
        XCTAssertEqual(dismissals, 1)
    }

    func testPanelHasAnAccessibleName() {
        let panel = NotchPanel(contentView: NSView())
        XCTAssertEqual(panel.title, "DropNotch")
    }
}
