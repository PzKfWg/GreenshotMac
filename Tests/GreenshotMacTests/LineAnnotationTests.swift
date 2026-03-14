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

    func testStartAndEndPoints() {
        let arrow = ArrowAnnotation(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        XCTAssertEqual(arrow.startPoint, CGPoint(x: 10, y: 20))
        XCTAssertEqual(arrow.endPoint, CGPoint(x: 110, y: 70))
    }

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
