import XCTest
import AppKit
@testable import GreenshotMac

@MainActor
final class LineAnnotationTests: XCTestCase {

    func testInitWithBoundsAndDefaultStyle() {
        let line = LineAnnotation(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        XCTAssertEqual(line.bounds, CGRect(x: 10, y: 20, width: 100, height: 50))
        XCTAssertFalse(line.isSelected)
        XCTAssertEqual(line.style.strokeWidth, 2.0)
    }

    func testStartAndEndPoints() {
        let line = LineAnnotation(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        XCTAssertEqual(line.startPoint, CGPoint(x: 10, y: 20))
        XCTAssertEqual(line.endPoint, CGPoint(x: 110, y: 70))
    }

    func testHitTestOnLine() {
        let line = LineAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 100))
        // Point on the line (midpoint)
        XCTAssertTrue(line.hitTest(point: CGPoint(x: 50, y: 50)))
    }

    func testHitTestNearLine() {
        let line = LineAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 0))
        // Horizontal line; point 5px above should still hit (within 6px tolerance)
        XCTAssertTrue(line.hitTest(point: CGPoint(x: 50, y: 5)))
    }

    func testHitTestFarFromLine() {
        let line = LineAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 0))
        // 20px away from horizontal line
        XCTAssertFalse(line.hitTest(point: CGPoint(x: 50, y: 20)))
    }

    func testHitTestOutsideSegmentRange() {
        let line = LineAnnotation(bounds: CGRect(x: 10, y: 10, width: 100, height: 0))
        // Point far beyond the segment endpoint
        XCTAssertFalse(line.hitTest(point: CGPoint(x: 200, y: 10)))
    }

    func testCopyCreatesIndependentAnnotation() {
        let original = LineAnnotation(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        let copy = original.copy()
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertEqual(copy.bounds, original.bounds)
        copy.bounds = CGRect(x: 0, y: 0, width: 50, height: 50)
        XCTAssertNotEqual(original.bounds, copy.bounds)
    }

    func testCustomStylePreserved() {
        var style = AnnotationStyle()
        style.strokeColor = .blue
        style.strokeWidth = 5.0
        style.shadow = .none
        let line = LineAnnotation(bounds: .zero, style: style)
        XCTAssertEqual(line.style.strokeWidth, 5.0)
        XCTAssertFalse(line.style.shadow.enabled)
    }

    func testHandleHitTestReturnsCorrectHandle() {
        let line = LineAnnotation(bounds: CGRect(x: 100, y: 100, width: 200, height: 150))
        line.isSelected = true
        let handle = line.handleHitTest(point: CGPoint(x: 100, y: 100))
        XCTAssertEqual(handle, .topLeft)
    }

    func testHandleHitTestReturnsNilForCenter() {
        let line = LineAnnotation(bounds: CGRect(x: 100, y: 100, width: 200, height: 150))
        line.isSelected = true
        let handle = line.handleHitTest(point: CGPoint(x: 200, y: 175))
        XCTAssertNil(handle)
    }

    func testZeroLengthLineHitTest() {
        let line = LineAnnotation(bounds: CGRect(x: 50, y: 50, width: 0, height: 0))
        XCTAssertTrue(line.hitTest(point: CGPoint(x: 50, y: 50)))
        XCTAssertFalse(line.hitTest(point: CGPoint(x: 60, y: 60)))
    }
}

@MainActor
final class ArrowAnnotationTests: XCTestCase {

    func testInitWithBoundsAndDefaultStyle() {
        let arrow = ArrowAnnotation(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        XCTAssertEqual(arrow.bounds, CGRect(x: 10, y: 20, width: 100, height: 50))
        XCTAssertFalse(arrow.isSelected)
        XCTAssertEqual(arrow.style.strokeWidth, 2.0)
    }

    func testDefaultArrowHeadIsEndPoint() {
        let arrow = ArrowAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 50))
        XCTAssertEqual(arrow.arrowHeads, .endPoint)
    }

    func testStartAndEndPoints() {
        let arrow = ArrowAnnotation(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        XCTAssertEqual(arrow.startPoint, CGPoint(x: 10, y: 20))
        XCTAssertEqual(arrow.endPoint, CGPoint(x: 110, y: 70))
    }

    // MARK: - ArrowHeadCombination

    func testArrowHeadCombinationNone() {
        let arrow = ArrowAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 0), arrowHeads: .none)
        XCTAssertEqual(arrow.arrowHeads, .none)
    }

    func testArrowHeadCombinationStartPoint() {
        let arrow = ArrowAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 0), arrowHeads: .startPoint)
        XCTAssertEqual(arrow.arrowHeads, .startPoint)
    }

    func testArrowHeadCombinationBoth() {
        let arrow = ArrowAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 0), arrowHeads: .both)
        XCTAssertEqual(arrow.arrowHeads, .both)
    }

    func testCopyPreservesArrowHeadCombination() {
        let original = ArrowAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 50), arrowHeads: .both)
        let copy = original.copy() as! ArrowAnnotation
        XCTAssertEqual(copy.arrowHeads, .both)
    }

    // MARK: - Arrowhead sizing (proportional to strokeWidth like Greenshot Windows)

    func testArrowheadPointsProportionalToStrokeWidth() {
        var style = AnnotationStyle()
        style.strokeWidth = 2.0
        let arrow = ArrowAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 0), style: style)
        let (p1, p2) = arrow.arrowheadPoints(tip: arrow.endPoint, towards: arrow.startPoint)

        // Width should be 4 * strokeWidth = 8, so half-width = 4
        // Height should be 6 * strokeWidth = 12
        // Base points should be ~12px behind the tip, ~4px apart from centerline
        let baseCenter = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
        let distFromTip = sqrt(pow(baseCenter.x - arrow.endPoint.x, 2) + pow(baseCenter.y - arrow.endPoint.y, 2))
        XCTAssertEqual(distFromTip, 12.0, accuracy: 0.1, "Arrowhead height should be 6 * strokeWidth")

        let baseWidth = sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2))
        XCTAssertEqual(baseWidth, 8.0, accuracy: 0.1, "Arrowhead width should be 4 * strokeWidth")
    }

    func testArrowheadScalesWithStrokeWidth() {
        var style = AnnotationStyle()
        style.strokeWidth = 5.0
        let arrow = ArrowAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 0), style: style)
        let (p1, p2) = arrow.arrowheadPoints(tip: arrow.endPoint, towards: arrow.startPoint)

        let baseWidth = sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2))
        XCTAssertEqual(baseWidth, 20.0, accuracy: 0.1, "Arrowhead width should be 4 * 5 = 20")
    }

    // MARK: - Hit testing

    func testHitTestOnLine() {
        let arrow = ArrowAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertTrue(arrow.hitTest(point: CGPoint(x: 50, y: 50)))
    }

    func testHitTestNearLine() {
        let arrow = ArrowAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 0))
        XCTAssertTrue(arrow.hitTest(point: CGPoint(x: 50, y: 5)))
    }

    func testHitTestFarFromLine() {
        let arrow = ArrowAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 0))
        XCTAssertFalse(arrow.hitTest(point: CGPoint(x: 50, y: 20)))
    }

    func testHitTestOnEndArrowhead() {
        // Arrow pointing right; arrowhead triangle at endpoint
        var style = AnnotationStyle()
        style.strokeWidth = 3.0
        let arrow = ArrowAnnotation(bounds: CGRect(x: 0, y: 50, width: 100, height: 0), style: style)
        // Point near the arrowhead tip area (slightly off the line axis)
        // Arrowhead width = 4*3 = 12 (half = 6), height = 6*3 = 18
        // So a point 5px above the line at x=95 should be inside the arrowhead
        XCTAssertTrue(arrow.hitTest(point: CGPoint(x: 95, y: 55)))
    }

    func testHitTestOnStartArrowheadWhenBoth() {
        var style = AnnotationStyle()
        style.strokeWidth = 3.0
        let arrow = ArrowAnnotation(bounds: CGRect(x: 0, y: 50, width: 100, height: 0), style: style, arrowHeads: .both)
        // Point near start arrowhead (x=5, y=55 should be inside)
        XCTAssertTrue(arrow.hitTest(point: CGPoint(x: 5, y: 55)))
    }

    func testHitTestMissesArrowheadWhenNone() {
        var style = AnnotationStyle()
        style.strokeWidth = 3.0
        let arrow = ArrowAnnotation(bounds: CGRect(x: 0, y: 50, width: 100, height: 0), style: style, arrowHeads: .none)
        // Point off-line near endpoint, not on arrowhead since none
        XCTAssertFalse(arrow.hitTest(point: CGPoint(x: 95, y: 58)))
    }

    func testHitTestToleranceScalesWithStrokeWidth() {
        var style = AnnotationStyle()
        style.strokeWidth = 8.0
        let arrow = ArrowAnnotation(bounds: CGRect(x: 0, y: 50, width: 200, height: 0), style: style)
        // Tolerance = max(6, 8+4) = 12, so 11px away should hit
        XCTAssertTrue(arrow.hitTest(point: CGPoint(x: 100, y: 61)))
        // 13px away should miss
        XCTAssertFalse(arrow.hitTest(point: CGPoint(x: 100, y: 63)))
    }

    // MARK: - Copy and style

    func testCopyCreatesIndependentAnnotation() {
        let original = ArrowAnnotation(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        let copy = original.copy()
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertEqual(copy.bounds, original.bounds)
        copy.bounds = CGRect(x: 0, y: 0, width: 50, height: 50)
        XCTAssertNotEqual(original.bounds, copy.bounds)
    }

    func testCustomStylePreserved() {
        var style = AnnotationStyle()
        style.strokeColor = .green
        style.strokeWidth = 4.0
        style.shadow = .none
        let arrow = ArrowAnnotation(bounds: .zero, style: style)
        XCTAssertEqual(arrow.style.strokeWidth, 4.0)
        XCTAssertFalse(arrow.style.shadow.enabled)
    }

    func testCopyReturnsArrowAnnotation() {
        let original = ArrowAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 100))
        let copy = original.copy()
        XCTAssertTrue(copy is ArrowAnnotation)
    }

    func testHandleHitTestReturnsCorrectHandle() {
        let arrow = ArrowAnnotation(bounds: CGRect(x: 100, y: 100, width: 200, height: 150))
        arrow.isSelected = true
        let handle = arrow.handleHitTest(point: CGPoint(x: 300, y: 250))
        XCTAssertEqual(handle, .bottomRight)
    }
}
