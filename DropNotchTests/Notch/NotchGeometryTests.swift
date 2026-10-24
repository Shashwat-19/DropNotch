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

    func testOpenFrameNeverSmallerThanPeekForAWideNotch() {
        // Notch wider than openSize: open must follow peek rather than shrink below it.
        let geometry = NotchGeometry(screenFrame: screen, safeAreaTop: inset, auxLeftWidth: 100,
                                     auxRightWidth: 100, menuBarHeight: inset, backingScale: 2)
        XCTAssertEqual(geometry.openFrame.width, geometry.peekFrame.width)
        XCTAssertTrue(geometry.openFrame.contains(geometry.peekFrame))
    }
}
