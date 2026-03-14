import XCTest
import AppKit
@testable import GreenshotMac

@MainActor
final class RectangleAnnotationTests: XCTestCase {

    func testInitWithBoundsAndDefaultStyle() {
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        XCTAssertEqual(rect.bounds, CGRect(x: 10, y: 20, width: 100, height: 50))
        XCTAssertFalse(rect.isSelected)
        XCTAssertEqual(rect.style.strokeWidth, 2.0)
    }

    func testHitTestInsideBounds() {
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        XCTAssertTrue(rect.hitTest(point: CGPoint(x: 50, y: 40)))
    }

    func testHitTestOutsideBounds() {
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        XCTAssertFalse(rect.hitTest(point: CGPoint(x: 200, y: 200)))
    }

    func testHitTestNearEdge() {
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        // 4px tolerance
        XCTAssertTrue(rect.hitTest(point: CGPoint(x: 7, y: 25)))
    }

    func testCopyCreatesIndependentAnnotation() {
        let original = RectangleAnnotation(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
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
        let rect = RectangleAnnotation(bounds: .zero, style: style)
        XCTAssertEqual(rect.style.strokeWidth, 5.0)
        XCTAssertFalse(rect.style.shadow.enabled)
    }

    func testHandleHitTestReturnsCorrectHandle() {
        let rect = RectangleAnnotation(bounds: CGRect(x: 100, y: 100, width: 200, height: 150))
        rect.isSelected = true
        let handle = rect.handleHitTest(point: CGPoint(x: 100, y: 100))
        XCTAssertEqual(handle, .topLeft)
    }

    func testHandleHitTestReturnsNilForCenter() {
        let rect = RectangleAnnotation(bounds: CGRect(x: 100, y: 100, width: 200, height: 150))
        rect.isSelected = true
        let handle = rect.handleHitTest(point: CGPoint(x: 200, y: 175))
        XCTAssertNil(handle)
    }
}
