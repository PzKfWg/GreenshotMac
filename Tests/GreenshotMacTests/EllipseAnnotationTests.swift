import XCTest
import AppKit
@testable import GreenshotMac

@MainActor
final class EllipseAnnotationTests: XCTestCase {

    func testInitWithBoundsAndDefaultStyle() {
        let ellipse = EllipseAnnotation(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        XCTAssertEqual(ellipse.bounds, CGRect(x: 10, y: 20, width: 100, height: 50))
        XCTAssertFalse(ellipse.isSelected)
        XCTAssertEqual(ellipse.style.strokeWidth, 2.0)
    }

    func testHitTestOnOutlineHits() {
        let ellipse = EllipseAnnotation(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        // Right edge of ellipse (110, 45) — on the outline, should hit
        XCTAssertTrue(ellipse.hitTest(point: CGPoint(x: 110, y: 45)))
    }

    func testHitTestCenterOfUnfilledMisses() {
        let ellipse = EllipseAnnotation(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        // Center of unfilled ellipse — inside outline ring, should miss
        XCTAssertFalse(ellipse.hitTest(point: CGPoint(x: 60, y: 45)))
    }

    func testHitTestOutsideBounds() {
        let ellipse = EllipseAnnotation(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        XCTAssertFalse(ellipse.hitTest(point: CGPoint(x: 200, y: 200)))
    }

    // MARK: - Ellipse equation hit test (aligned with Greenshot Windows)

    func testHitTestAtCornerOfBoundsForUnfilledEllipse() {
        // Unfilled ellipse — corner of bounding box should NOT hit
        // because the corner is outside the ellipse outline
        let ellipse = EllipseAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 100))
        // Corner (0,0) is far from the outline of a circle centered at (50,50) r=50
        XCTAssertFalse(ellipse.hitTest(point: CGPoint(x: 0, y: 0)))
    }

    func testHitTestOnEllipseOutline() {
        // Unfilled ellipse centered at (50,50) with width=100, height=100
        // Top of ellipse is at (50, 0) — should hit within tolerance
        let ellipse = EllipseAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertTrue(ellipse.hitTest(point: CGPoint(x: 50, y: 0)))
    }

    func testHitTestInsideUnfilledEllipseMisses() {
        // Unfilled ellipse — point well inside the outline should miss
        // since we only test the border region
        let ellipse = EllipseAnnotation(bounds: CGRect(x: 0, y: 0, width: 200, height: 200))
        // Center (100,100) is way inside the outline
        XCTAssertFalse(ellipse.hitTest(point: CGPoint(x: 100, y: 100)))
    }

    func testHitTestInsideFilledEllipseHits() {
        // Filled ellipse — center should hit
        var style = AnnotationStyle()
        style.fillColor = .red
        let ellipse = EllipseAnnotation(bounds: CGRect(x: 0, y: 0, width: 200, height: 200), style: style)
        XCTAssertTrue(ellipse.hitTest(point: CGPoint(x: 100, y: 100)))
    }

    func testHitTestFilledEllipseCornerMisses() {
        // Filled ellipse — corner of bounding rect is outside the ellipse
        var style = AnnotationStyle()
        style.fillColor = .red
        let ellipse = EllipseAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 100), style: style)
        // Corner (2, 2) is well outside the circle for a 100x100 circle
        XCTAssertFalse(ellipse.hitTest(point: CGPoint(x: 2, y: 2)))
    }

    func testHitTestNarrowEllipse() {
        // Very narrow ellipse (tall and thin) — test uses proper equation
        let ellipse = EllipseAnnotation(bounds: CGRect(x: 0, y: 0, width: 20, height: 200))
        // On the outline at top: (10, 0) — should hit
        XCTAssertTrue(ellipse.hitTest(point: CGPoint(x: 10, y: 0)))
        // Far to the side: (30, 100) — outside even with tolerance
        XCTAssertFalse(ellipse.hitTest(point: CGPoint(x: 30, y: 100)))
    }

    // MARK: - Copy and style

    func testCopyCreatesIndependentAnnotation() {
        let original = EllipseAnnotation(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
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
        let ellipse = EllipseAnnotation(bounds: .zero, style: style)
        XCTAssertEqual(ellipse.style.strokeWidth, 5.0)
        XCTAssertFalse(ellipse.style.shadow.enabled)
    }
}
