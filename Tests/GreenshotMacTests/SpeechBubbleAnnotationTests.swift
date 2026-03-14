import XCTest
import AppKit
@testable import GreenshotMac

@MainActor
final class SpeechBubbleAnnotationTests: XCTestCase {

    func testInitWithDefaultValues() {
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 50, y: 100, width: 200, height: 80))
        XCTAssertEqual(bubble.bounds, CGRect(x: 50, y: 100, width: 200, height: 80))
        XCTAssertEqual(bubble.text, "Text")
        // In flipped coords, maxY=180 is the bottom edge; tail at maxY+30=210
        XCTAssertEqual(bubble.tailPoint, CGPoint(x: 150, y: 210))
        XCTAssertFalse(bubble.isSelected)
        XCTAssertEqual(bubble.style.strokeWidth, 2.0)
    }

    func testHitTestInBodyArea() {
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 50, y: 100, width: 200, height: 80))
        // Point inside the body
        XCTAssertTrue(bubble.hitTest(point: CGPoint(x: 100, y: 140)))
    }

    func testHitTestOutside() {
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 50, y: 100, width: 200, height: 80))
        // Point far away from both body and tail
        XCTAssertFalse(bubble.hitTest(point: CGPoint(x: 500, y: 500)))
    }

    func testCopyPreservesTextAndTailPoint() {
        let customTail = CGPoint(x: 200, y: 50)
        let original = SpeechBubbleAnnotation(
            bounds: CGRect(x: 10, y: 20, width: 100, height: 60),
            text: "Hello",
            tailPoint: customTail
        )
        let copy = original.copy()

        guard let bubbleCopy = copy as? SpeechBubbleAnnotation else {
            XCTFail("Copy should return a SpeechBubbleAnnotation")
            return
        }

        XCTAssertNotEqual(bubbleCopy.id, original.id)
        XCTAssertEqual(bubbleCopy.text, "Hello")
        XCTAssertEqual(bubbleCopy.tailPoint, customTail)
        XCTAssertEqual(bubbleCopy.bounds, original.bounds)
        XCTAssertEqual(bubbleCopy.style, original.style)
    }

    func testTailPointCanBeChanged() {
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 50, y: 100, width: 200, height: 80))
        let originalTail = bubble.tailPoint

        let newTail = CGPoint(x: 300, y: 10)
        bubble.tailPoint = newTail

        XCTAssertNotEqual(bubble.tailPoint, originalTail)
        XCTAssertEqual(bubble.tailPoint, newTail)
    }
}
