import XCTest
import AppKit
@testable import GreenshotMac

@MainActor
final class TextAnnotationTests: XCTestCase {

    func testInitWithDefaultText() {
        let annotation = TextAnnotation(bounds: CGRect(x: 10, y: 20, width: 200, height: 50))
        XCTAssertEqual(annotation.text, "Text")
        XCTAssertEqual(annotation.bounds, CGRect(x: 10, y: 20, width: 200, height: 50))
        XCTAssertFalse(annotation.isSelected)
    }

    func testHitTestInsideBounds() {
        let annotation = TextAnnotation(bounds: CGRect(x: 10, y: 20, width: 200, height: 50))
        XCTAssertTrue(annotation.hitTest(point: CGPoint(x: 100, y: 40)))
    }

    func testHitTestOutsideBounds() {
        let annotation = TextAnnotation(bounds: CGRect(x: 10, y: 20, width: 200, height: 50))
        XCTAssertFalse(annotation.hitTest(point: CGPoint(x: 300, y: 300)))
    }

    func testCopyPreservesText() {
        let original = TextAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 40), text: "Hello")
        let copy = original.copy()
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertEqual(copy.bounds, original.bounds)
        guard let textCopy = copy as? TextAnnotation else {
            XCTFail("Copy should be a TextAnnotation")
            return
        }
        XCTAssertEqual(textCopy.text, "Hello")
    }

    func testCustomStylePreserved() {
        var style = AnnotationStyle()
        style.strokeColor = .blue
        style.fontSize = 24.0
        style.fontName = "Courier"
        style.shadow = .none
        let annotation = TextAnnotation(bounds: .zero, style: style)
        XCTAssertEqual(annotation.style.fontSize, 24.0)
        XCTAssertEqual(annotation.style.fontName, "Courier")
        XCTAssertFalse(annotation.style.shadow.enabled)
    }
}
