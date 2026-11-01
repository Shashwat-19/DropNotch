import XCTest
@testable import DropNotch

final class NotchGeometryTests: XCTestCase {
    // Made-up values, not real Mac measurements.
    private let screen = CGRect(x: 0, y: 0, width: 1500, height: 1000)
    private let left: CGFloat = 640
    private let right: CGFloat = 660
    private let inset: CGFloat = 32

    private func notched(_ frame: CGRect, inset: CGFloat = 32, scale: CGFloat = 2) -> NotchGeometry {
        NotchGeometry(screenFrame: frame, safeAreaTop: inset, auxLeftWidth: left, auxRightWidth: right,
                      menuBarHeight: inset, backingScale: scale)
    }

    private func plain(_ frame: CGRect, menuBarHeight: CGFloat = 25) -> NotchGeometry {
        NotchGeometry(screenFrame: frame, safeAreaTop: 0, auxLeftWidth: nil, auxRightWidth: nil,
                      menuBarHeight: menuBarHeight, backingScale: 2)
    }

    func testNotchedScreenClosedFrameMatchesNotch() {
        let geometry = notched(screen)
        XCTAssertTrue(geometry.hasNotch)
        XCTAssertEqual(geometry.closedFrame.width, screen.width - left - right)
        XCTAssertEqual(geometry.closedFrame.minX, screen.minX + left)
        XCTAssertEqual(geometry.closedFrame.maxY, screen.maxY)
        XCTAssertEqual(geometry.closedFrame.height, inset)
    }

    func testSecondaryDisplayOriginShiftsEveryFrame() {
        let base = notched(screen)
        for origin in [CGPoint(x: 1500, y: 200), CGPoint(x: -1920, y: -300)] {
            let shifted = notched(screen.offsetBy(dx: origin.x, dy: origin.y))
            XCTAssertEqual(shifted.closedFrame, base.closedFrame.offsetBy(dx: origin.x, dy: origin.y))
            XCTAssertEqual(shifted.peekFrame, base.peekFrame.offsetBy(dx: origin.x, dy: origin.y))
            XCTAssertEqual(shifted.openFrame, base.openFrame.offsetBy(dx: origin.x, dy: origin.y))
        }
    }

    func testNoNotchOnOffsetScreenCentresOnThatScreen() {
        let frame = CGRect(x: -1920, y: -300, width: 1920, height: 1080)
        let geometry = plain(frame)
        XCTAssertEqual(geometry.closedFrame.midX, frame.midX)
        XCTAssertEqual(geometry.closedFrame.maxY, frame.maxY)
    }

    func testNoNotchDrawsPillMatchingMenuBarHeight() {
        let geometry = plain(screen, menuBarHeight: 25)
        XCTAssertFalse(geometry.hasNotch)
        XCTAssertEqual(geometry.closedFrame.midX, screen.midX)
        XCTAssertEqual(geometry.closedFrame.width, NotchGeometry.pillWidth)
        XCTAssertEqual(geometry.closedFrame.height, 25)
        XCTAssertEqual(geometry.closedFrame.maxY, screen.maxY)
    }

    func testAutoHiddenMenuBarUsesFallbackHeight() {
        let geometry = plain(screen, menuBarHeight: 0)
        XCTAssertEqual(geometry.closedFrame.height, NotchGeometry.fallbackPillHeight)
        XCTAssertEqual(geometry.closedFrame.maxY, screen.maxY)
    }

    func testInsetWithoutBothAuxiliaryAreasIsTreatedAsNoNotch() {
        for (auxLeft, auxRight) in [(left, nil), (nil, right), (nil, nil)] as [(CGFloat?, CGFloat?)] {
            let geometry = NotchGeometry(screenFrame: screen, safeAreaTop: inset, auxLeftWidth: auxLeft,
                                         auxRightWidth: auxRight, menuBarHeight: 25, backingScale: 2)
            XCTAssertFalse(geometry.hasNotch)
            XCTAssertEqual(geometry.closedFrame.width, NotchGeometry.pillWidth)
            XCTAssertEqual(geometry.closedFrame.height, 25)
        }
    }

    func testFractionalInsetIsKeptOnRetinaAndRoundedOnStandardDisplay() {
        XCTAssertEqual(notched(screen, inset: 33.5, scale: 2).closedFrame.height, 33.5)
        // The bottom edge sits at a half point; at scale 1 it rounds half up, so the frame is 33 tall.
        XCTAssertEqual(notched(screen, inset: 33.5, scale: 1).closedFrame.height, 33)
    }

    func testEveryEdgeLandsOnAWholeDevicePixel() {
        // Odd widths and a fractional origin force half-point centres before rounding.
        let frame = CGRect(x: 0.25, y: -0.75, width: 1501, height: 999)
        for scale: CGFloat in [1, 2] {
            let geometries = [notched(frame, inset: 33.5, scale: scale),
                              NotchGeometry(screenFrame: frame, safeAreaTop: 0, auxLeftWidth: nil,
                                            auxRightWidth: nil, menuBarHeight: 24.5, backingScale: scale)]
            for geometry in geometries {
                for rect in [geometry.closedFrame, geometry.peekFrame, geometry.openFrame] {
                    for edge in [rect.minX, rect.maxX, rect.minY, rect.maxY] {
                        let pixels = edge * scale
                        XCTAssertEqual(pixels, pixels.rounded(), "edge \(edge) at scale \(scale)")
                    }
                }
            }
        }
    }

    func testPeekAndOpenFramesGrowFromTheClosedFrame() {
        for geometry in [notched(screen), notched(screen, inset: 33.5, scale: 1), plain(screen)] {
            let closed = geometry.closedFrame
            // Centring an odd pixel width can shift midX by up to one pixel.
            let tolerance: CGFloat = 1
            for rect in [geometry.peekFrame, geometry.openFrame] {
                XCTAssertTrue(rect.contains(closed))
                XCTAssertEqual(rect.maxY, closed.maxY)
                XCTAssertEqual(rect.midX, closed.midX, accuracy: tolerance)
            }
            XCTAssertEqual(geometry.peekFrame.width, closed.width + NotchGeometry.peekGrowth.width,
                           accuracy: tolerance)
            XCTAssertEqual(geometry.peekFrame.height, closed.height + NotchGeometry.peekGrowth.height,
                           accuracy: tolerance)
            XCTAssertGreaterThanOrEqual(geometry.openFrame.width, NotchGeometry.openSize.width - tolerance)
            XCTAssertGreaterThanOrEqual(geometry.openFrame.height, NotchGeometry.openSize.height - tolerance)
        }
    }

    func testFrameForPhaseReturnsMatchingFrame() {
        let geometry = notched(screen)
        XCTAssertEqual(geometry.frame(for: .closed), geometry.closedFrame)
        XCTAssertEqual(geometry.frame(for: .peek), geometry.peekFrame)
        XCTAssertEqual(geometry.frame(for: .open), geometry.openFrame)
    }

    func testOpenFrameNeverSmallerThanPeekForAWideNotch() {
        // Notch wider than openSize: open must follow the widest peek (compact, D28) rather than shrink below it, and
        // leave room for the top row right of the housing (D35).
        let geometry = NotchGeometry(screenFrame: screen, safeAreaTop: inset, auxLeftWidth: 100,
                                     auxRightWidth: 100, menuBarHeight: inset, backingScale: 2)
        XCTAssertEqual(geometry.openFrame.width,
                       max(geometry.compactPeekFrame.width, geometry.closedFrame.width + 2 * NotchGeometry.topRowWidth))
        XCTAssertTrue(geometry.openFrame.contains(geometry.peekFrame))
        XCTAssertTrue(geometry.openFrame.contains(geometry.compactPeekFrame))
    }

    // The panel reaches above the screen so the top pixel row counts as inside (D20).
    func testPanelFrameAddsTheTopOverhangOnly() {
        let geometry = notched(screen)
        for phase in [NotchHoverStateMachine.Phase.closed, .peek, .open] {
            let shape = geometry.frame(for: phase), panel = geometry.panelFrame(for: phase)
            XCTAssertEqual(panel.minX, shape.minX, "\(phase)")
            XCTAssertEqual(panel.minY, shape.minY, "\(phase)")
            XCTAssertEqual(panel.width, shape.width, "\(phase)")
            XCTAssertEqual(panel.maxY, screen.maxY + NotchGeometry.topOverhang, "\(phase)")
        }
        XCTAssertEqual(NotchGeometry.topOverhang, 1)
    }
    // MARK: Compact slots (D28)

    func testCompactFrameAddsASquareWingEachSideOfTheNotch() {
        let geometry = notched(screen)
        let closed = geometry.closedFrame
        XCTAssertEqual(geometry.wingWidth, inset)
        XCTAssertEqual(geometry.compactFrame, CGRect(x: closed.minX - inset, y: closed.minY,
                                                     width: closed.width + 2 * inset, height: closed.height))
        XCTAssertEqual(geometry.compactFrame.midX, closed.midX)
        XCTAssertEqual(geometry.compactFrame.maxY, screen.maxY)
    }

    func testCompactPeekFrameGrowsFromTheCompactFrame() {
        for geometry in [notched(screen), notched(screen, inset: 33.5, scale: 2), plain(screen)] {
            let compact = geometry.compactFrame, peek = geometry.compactPeekFrame
            XCTAssertEqual(peek.width, compact.width + NotchGeometry.peekGrowth.width)
            XCTAssertEqual(peek.height, compact.height + NotchGeometry.peekGrowth.height)
            XCTAssertEqual(peek.maxY, compact.maxY)
            XCTAssertEqual(peek.midX, compact.midX)
            XCTAssertTrue(peek.contains(compact))
            XCTAssertTrue(peek.contains(geometry.peekFrame))
        }
    }

    func testPillWithoutANotchAlsoGetsWings() {
        let geometry = plain(screen, menuBarHeight: 25)
        XCTAssertEqual(geometry.wingWidth, 25)
        XCTAssertEqual(geometry.compactFrame.width, NotchGeometry.pillWidth + 50)
        XCTAssertEqual(geometry.compactFrame.height, 25)
        XCTAssertEqual(geometry.compactFrame.midX, screen.midX)
        XCTAssertEqual(geometry.compactFrame.maxY, screen.maxY)
    }

    func testFrameForPhasePicksTheCompactVariantsWhileClosedOrPeeking() {
        let geometry = notched(screen)
        XCTAssertEqual(geometry.frame(for: .closed, compact: true), geometry.compactFrame)
        XCTAssertEqual(geometry.frame(for: .peek, compact: true), geometry.compactPeekFrame)
        XCTAssertEqual(geometry.frame(for: .open, compact: true), geometry.openFrame)
        XCTAssertEqual(geometry.frame(for: .closed, compact: false), geometry.closedFrame)
        XCTAssertEqual(geometry.frame(for: .peek, compact: false), geometry.peekFrame)
        XCTAssertEqual(geometry.frame(for: .open, compact: false), geometry.openFrame)
    }

    func testCompactPanelFrameAddsTheTopOverhangOnly() {
        let geometry = notched(screen)
        for phase in [NotchHoverStateMachine.Phase.closed, .peek, .open] {
            let shape = geometry.frame(for: phase, compact: true), panel = geometry.panelFrame(for: phase, compact: true)
            XCTAssertEqual(panel, CGRect(x: shape.minX, y: shape.minY, width: shape.width,
                                         height: shape.height + NotchGeometry.topOverhang), "\(phase)")
        }
        XCTAssertEqual(geometry.panelFrame(for: .open, compact: true), geometry.panelFrame(for: .open))
    }

    // The open frame is the canvas for every shape (D19), so it must hold the compact ones too.
    func testOpenFrameContainsEveryFrame() {
        for geometry in [notched(screen), notched(screen, inset: 33.5, scale: 1), plain(screen),
                         NotchGeometry(screenFrame: screen, safeAreaTop: inset, auxLeftWidth: 100,
                                       auxRightWidth: 100, menuBarHeight: inset, backingScale: 2)] {
            for rect in [geometry.closedFrame, geometry.peekFrame, geometry.compactFrame, geometry.compactPeekFrame] {
                XCTAssertTrue(geometry.openFrame.contains(rect), "\(rect)")
            }
        }
    }

    func testCompactFramesStayPixelAlignedForAFractionalInset() {
        let geometry = notched(screen, inset: 33.5, scale: 2)
        XCTAssertEqual(geometry.wingWidth, 33.5)
        XCTAssertEqual(geometry.compactFrame.height, 33.5)
        XCTAssertEqual(geometry.compactFrame.width, geometry.closedFrame.width + 67)
        let frame = CGRect(x: 0.25, y: -0.75, width: 1501, height: 999)
        for scale: CGFloat in [1, 2] {
            let fractional = notched(frame, inset: 33.5, scale: scale)
            for rect in [fractional.compactFrame, fractional.compactPeekFrame] {
                for edge in [rect.minX, rect.maxX, rect.minY, rect.maxY] {
                    let pixels = edge * scale
                    XCTAssertEqual(pixels, pixels.rounded(), "edge \(edge) at scale \(scale)")
                }
            }
        }
    }

    // MARK: Top row right of the camera housing (D35)

    /// A MacBook Air-like screen: 1470 × 956 pt with a 208 pt housing. Approximate, not a measured value.
    private let air = CGRect(x: 0, y: 0, width: 1470, height: 956)

    private func notched(_ frame: CGRect, left: CGFloat, right: CGFloat) -> NotchGeometry {
        NotchGeometry(screenFrame: frame, safeAreaTop: inset, auxLeftWidth: left, auxRightWidth: right,
                      menuBarHeight: inset, backingScale: 2)
    }

    /// The row sits right-aligned in the open shape; the housing is the closed frame, both in the open shape's local x.
    private func assertRowClearOfHousing(_ geometry: NotchGeometry, file: StaticString = #filePath, line: UInt = #line) {
        let open = geometry.openFrame
        XCTAssertGreaterThanOrEqual(open.width - geometry.openTopRowLeading, NotchGeometry.topRowWidth,
                                    file: file, line: line)
        let housing = (geometry.closedFrame.minX - open.minX)...geometry.openTopRowLeading
        let row = (open.width - NotchGeometry.topRowWidth + NotchGeometry.topRowInset)...(open.width - NotchGeometry.topRowInset)
        XCTAssertFalse(housing.overlaps(row), "housing \(housing) row \(row)", file: file, line: line)
    }

    func testTopRowWidthFitsFiveItems() {
        XCTAssertEqual(NotchGeometry.topRowWidth, 5 * 28 + 4 * 2 + 2 * 8)
        XCTAssertEqual(NotchGeometry.topRowWidth, 164)
    }

    func testAirLikeScreenTopRowClearsTheHousing() {
        let side = (air.width - 208) / 2
        let geometry = notched(air, left: side, right: side)
        XCTAssertEqual(geometry.closedFrame.width, 208)
        XCTAssertEqual(geometry.openFrame.width, 536)
        XCTAssertEqual(geometry.openFrame.midX, geometry.closedFrame.midX)
        XCTAssertEqual(geometry.openTopRowLeading, geometry.closedFrame.maxX - geometry.openFrame.minX)
        assertRowClearOfHousing(geometry)
    }

    func testOffCentreNotchTopRowStartsAtTheHousingEdge() {
        let geometry = notched(air, left: 600, right: 662)
        XCTAssertEqual(geometry.closedFrame.minX, 600)
        XCTAssertEqual(geometry.openFrame.midX, geometry.closedFrame.midX)
        XCTAssertEqual(geometry.openTopRowLeading, geometry.closedFrame.maxX - geometry.openFrame.minX)
        assertRowClearOfHousing(geometry)
    }

    func testOpenWidthIsTheWidestOfMinimumPeekAndTopRow() {
        // Wide: housing 1300 pt. Narrow: housing 100 pt, where the 480 pt minimum wins.
        for (left, right, expected) in [(100, 100, 1628), (700, 700, 480)] as [(CGFloat, CGFloat, CGFloat)] {
            let geometry = notched(screen, left: left, right: right)
            XCTAssertEqual(geometry.openFrame.width,
                           max(NotchGeometry.openSize.width, geometry.compactPeekFrame.width,
                               geometry.closedFrame.width + 2 * NotchGeometry.topRowWidth))
            XCTAssertEqual(geometry.openFrame.width, expected)
            assertRowClearOfHousing(geometry)
        }
    }

    func testPillIsNotWidenedForTheTopRow() {
        let geometry = plain(air)
        XCTAssertEqual(geometry.openFrame.width, NotchGeometry.openSize.width)
        XCTAssertEqual(geometry.openTopRowLeading, geometry.openFrame.width / 2)
        XCTAssertGreaterThanOrEqual(geometry.openFrame.width / 2, NotchGeometry.topRowWidth)
    }
}
