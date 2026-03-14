import XCTest
import AppKit
@testable import GreenshotMac

@MainActor
final class PixelateFilterTests: XCTestCase {

    func testInitWithBoundsAndDefaultStyle() {
        let filter = PixelateFilter(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        XCTAssertEqual(filter.bounds, CGRect(x: 10, y: 20, width: 100, height: 50))
        XCTAssertFalse(filter.isSelected)
        XCTAssertEqual(filter.style.strokeWidth, 2.0)
    }

    func testHitTestInsideBounds() {
        let filter = PixelateFilter(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        XCTAssertTrue(filter.hitTest(point: CGPoint(x: 50, y: 40)))
    }

    func testHitTestOutsideBounds() {
        let filter = PixelateFilter(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        XCTAssertFalse(filter.hitTest(point: CGPoint(x: 200, y: 200)))
    }

    func testHitTestNearEdge() {
        let filter = PixelateFilter(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        // 4px tolerance
        XCTAssertTrue(filter.hitTest(point: CGPoint(x: 7, y: 25)))
    }

    func testCopyCreatesIndependentAnnotation() {
        let original = PixelateFilter(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        let copy = original.copy()
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertEqual(copy.bounds, original.bounds)
        copy.bounds = CGRect(x: 0, y: 0, width: 50, height: 50)
        XCTAssertNotEqual(original.bounds, copy.bounds)
    }

    func testHandleHitTestReturnsCorrectHandle() {
        let filter = PixelateFilter(bounds: CGRect(x: 100, y: 100, width: 200, height: 150))
        filter.isSelected = true
        let handle = filter.handleHitTest(point: CGPoint(x: 100, y: 100))
        XCTAssertEqual(handle, .topLeft)
    }

    func testHandleHitTestReturnsNilForCenter() {
        let filter = PixelateFilter(bounds: CGRect(x: 100, y: 100, width: 200, height: 150))
        filter.isSelected = true
        let handle = filter.handleHitTest(point: CGPoint(x: 200, y: 175))
        XCTAssertNil(handle)
    }
}

@MainActor
final class HighlightFilterTests: XCTestCase {

    func testInitWithDefaultStyle() {
        let filter = HighlightFilter(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        XCTAssertEqual(filter.bounds, CGRect(x: 10, y: 20, width: 100, height: 50))
        XCTAssertFalse(filter.isSelected)
        // Default fill should be yellow at 40% opacity
        XCTAssertNotEqual(filter.style.fillColor, .clear)
        // Shadow should be disabled
        XCTAssertFalse(filter.style.shadow.enabled)
    }

    func testHitTestInsideBounds() {
        let filter = HighlightFilter(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        XCTAssertTrue(filter.hitTest(point: CGPoint(x: 50, y: 40)))
    }

    func testHitTestOutsideBounds() {
        let filter = HighlightFilter(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        XCTAssertFalse(filter.hitTest(point: CGPoint(x: 200, y: 200)))
    }

    func testHitTestNearEdge() {
        let filter = HighlightFilter(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        // 4px tolerance
        XCTAssertTrue(filter.hitTest(point: CGPoint(x: 7, y: 25)))
    }

    func testCopyCreatesIndependentAnnotation() {
        let original = HighlightFilter(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        let copy = original.copy()
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertEqual(copy.bounds, original.bounds)
        copy.bounds = CGRect(x: 0, y: 0, width: 50, height: 50)
        XCTAssertNotEqual(original.bounds, copy.bounds)
    }

    func testCustomStylePreserved() {
        var style = AnnotationStyle()
        style.fillColor = .green.withAlphaComponent(0.5)
        style.shadow = .none
        let filter = HighlightFilter(bounds: .zero, style: style)
        XCTAssertFalse(filter.style.shadow.enabled)
    }

    func testHandleHitTestReturnsCorrectHandle() {
        let filter = HighlightFilter(bounds: CGRect(x: 100, y: 100, width: 200, height: 150))
        filter.isSelected = true
        let handle = filter.handleHitTest(point: CGPoint(x: 100, y: 100))
        XCTAssertEqual(handle, .topLeft)
    }

    func testHandleHitTestReturnsNilForCenter() {
        let filter = HighlightFilter(bounds: CGRect(x: 100, y: 100, width: 200, height: 150))
        filter.isSelected = true
        let handle = filter.handleHitTest(point: CGPoint(x: 200, y: 175))
        XCTAssertNil(handle)
    }
}
