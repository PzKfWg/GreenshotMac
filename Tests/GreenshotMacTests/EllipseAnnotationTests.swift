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

    func testHitTestInsideBounds() {
        let ellipse = EllipseAnnotation(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        XCTAssertTrue(ellipse.hitTest(point: CGPoint(x: 50, y: 40)))
    }

    func testHitTestOutsideBounds() {
        let ellipse = EllipseAnnotation(bounds: CGRect(x: 10, y: 20, width: 100, height: 50))
        XCTAssertFalse(ellipse.hitTest(point: CGPoint(x: 200, y: 200)))
    }

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
