import SwiftUI
import XCTest
@testable import DropNotch

final class NotchShapeTests: XCTestCase {
    // SwiftUI's y axis points down: minY is the top edge, against the menu bar.
    private let rect = CGRect(x: 10, y: 20, width: 200, height: 40)

    private func assertRect(_ actual: CGRect, equals expected: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        for (a, e) in [(actual.minX, expected.minX), (actual.minY, expected.minY),
                       (actual.width, expected.width), (actual.height, expected.height)] {
            XCTAssertEqual(a, e, accuracy: 1e-6, "\(actual) vs \(expected)", file: file, line: line)
        }
    }

    func testBoundingBoxIsTheRect() {
        for (shoulder, radius) in [(0, 0), (0, 10), (6, 10), (10, 18)] as [(CGFloat, CGFloat)] {
            let path = NotchShape(shoulder: shoulder, bottomRadius: radius).path(in: rect)
            assertRect(path.boundingRect, equals: rect)
        }
    }

    func testWithoutAShoulderTheTopCornersAreSquare() {
        let path = NotchShape(shoulder: 0, bottomRadius: 10).path(in: rect)
        XCTAssertTrue(path.contains(CGPoint(x: rect.minX + 0.5, y: rect.minY + 0.5)))
        XCTAssertTrue(path.contains(CGPoint(x: rect.maxX - 0.5, y: rect.minY + 0.5)))
    }

    func testShouldersCurveInwardsFromTheTopEdge() {
        let shoulder: CGFloat = 6
        let path = NotchShape(shoulder: shoulder, bottomRadius: 10).path(in: rect)
        let left = rect.minX + shoulder, right = rect.maxX - shoulder
        // Inside the shoulder's circle, left of the body: menu bar shows through.
        XCTAssertFalse(path.contains(CGPoint(x: rect.minX + 0.5, y: rect.minY + 0.5)))
        XCTAssertFalse(path.contains(CGPoint(x: rect.maxX - 0.5, y: rect.minY + 0.5)))
        // Beside the body, below the shoulder.
        XCTAssertFalse(path.contains(CGPoint(x: rect.minX + 1, y: rect.minY + shoulder + 2)))
        // On the top row, in the corner the shoulder fills next to the body.
        XCTAssertTrue(path.contains(CGPoint(x: left - 0.5, y: rect.minY + 0.5)))
        XCTAssertTrue(path.contains(CGPoint(x: right + 0.5, y: rect.minY + 0.5)))
        XCTAssertTrue(path.contains(CGPoint(x: rect.midX, y: rect.midY)))
    }

    func testBottomCornersAreRounded() {
        for shoulder: CGFloat in [0, 6] {
            let path = NotchShape(shoulder: shoulder, bottomRadius: 10).path(in: rect)
            let left = rect.minX + shoulder, right = rect.maxX - shoulder
            XCTAssertFalse(path.contains(CGPoint(x: left + 0.5, y: rect.maxY - 0.5)), "shoulder \(shoulder)")
            XCTAssertFalse(path.contains(CGPoint(x: right - 0.5, y: rect.maxY - 0.5)), "shoulder \(shoulder)")
            XCTAssertTrue(path.contains(CGPoint(x: rect.midX, y: rect.maxY - 0.5)), "shoulder \(shoulder)")
        }
    }

    func testOversizedAndNegativeRadiiAreClamped() {
        let small = CGRect(x: 0, y: 0, width: 20, height: 10)
        for (shoulder, radius) in [(1000, 1000), (-5, -5), (1000, 0), (0, 1000)] as [(CGFloat, CGFloat)] {
            let path = NotchShape(shoulder: shoulder, bottomRadius: radius).path(in: small)
            let box = path.boundingRect
            let label = "shoulder \(shoulder) radius \(radius)"
            XCTAssertFalse(path.isEmpty, label)
            XCTAssertTrue([box.minX, box.minY, box.width, box.height].allSatisfy(\.isFinite), label)
            assertRect(box, equals: small)
            XCTAssertTrue(path.contains(CGPoint(x: small.midX, y: small.midY)), label)
        }
        // A zero rect still draws nothing invalid.
        let zero = NotchShape(shoulder: 6, bottomRadius: 10).path(in: .zero).boundingRect
        XCTAssertTrue([zero.minX, zero.minY, zero.width, zero.height].allSatisfy(\.isFinite))
    }

    func testAnimatableDataRoundTrips() {
        var shape = NotchShape(shoulder: 6, bottomRadius: 10)
        XCTAssertEqual(shape.animatableData.first, 6)
        XCTAssertEqual(shape.animatableData.second, 10)
        shape.animatableData = AnimatablePair(10, 18)
        XCTAssertEqual(shape.shoulder, 10)
        XCTAssertEqual(shape.bottomRadius, 18)
    }
}
