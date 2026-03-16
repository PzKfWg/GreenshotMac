import XCTest
import AppKit
@testable import GreenshotMac

@MainActor
final class SpeechBubbleAnnotationTests: XCTestCase {

    func testInitWithDefaultValues() {
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 50, y: 100, width: 200, height: 80))
        XCTAssertEqual(bubble.bounds, CGRect(x: 50, y: 100, width: 200, height: 80))
        XCTAssertEqual(bubble.text, "Texte")
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

    // MARK: - Default style (aligned with Greenshot Windows)

    func testDefaultStyleIsBlueStroke() {
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 50))
        XCTAssertEqual(bubble.style.strokeColor, .systemBlue)
    }

    func testDefaultStyleIsWhiteFill() {
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 50))
        XCTAssertEqual(bubble.style.fillColor, .white)
    }

    func testDefaultStyleIsBold() {
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 50))
        XCTAssertTrue(bubble.style.fontBold)
    }

    func testDefaultStyleFontSize20() {
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 50))
        XCTAssertEqual(bubble.style.fontSize, 20.0)
    }

    func testDefaultStyleNoShadow() {
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 50))
        XCTAssertFalse(bubble.style.shadow.enabled)
    }

    // MARK: - Corner radius (configurable stored property)

    func testCornerRadiusDefault() {
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 0, y: 0, width: 200, height: 80))
        XCTAssertEqual(bubble.cornerRadius, 20.0)
    }

    func testCornerRadiusCustomValue() {
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 0, y: 0, width: 200, height: 80), cornerRadius: 10)
        XCTAssertEqual(bubble.cornerRadius, 10.0)
    }

    func testCornerRadiusZero() {
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 0, y: 0, width: 200, height: 80), cornerRadius: 0)
        XCTAssertEqual(bubble.cornerRadius, 0.0)
    }

    func testCornerRadiusPreservedOnCopy() {
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 0, y: 0, width: 200, height: 80), cornerRadius: 15)
        let copy = bubble.copy() as! SpeechBubbleAnnotation
        XCTAssertEqual(copy.cornerRadius, 15.0)
    }

    // MARK: - Tail width (aligned with Greenshot Windows formula)

    func testTailWidthFormula() {
        // (|200| + |80|) / 20 = 14, capped to min(100, min(40, 14)) = 14
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 0, y: 0, width: 200, height: 80))
        XCTAssertEqual(bubble.tailWidth, 14.0)
    }

    func testTailWidthCappedToHalfSmallDimension() {
        // (|20| + |10|) / 20 = 1.5 → min(10, min(5, 1.5)) = 1.5
        // But minimum is 4, so = 4
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 0, y: 0, width: 20, height: 10))
        XCTAssertEqual(bubble.tailWidth, 4.0)
    }

    func testTailWidthLargeBubble() {
        // (|600| + |400|) / 20 = 50, capped to min(300, min(200, 50)) = 50
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 0, y: 0, width: 600, height: 400))
        XCTAssertEqual(bubble.tailWidth, 50.0)
    }

    // MARK: - Custom style override

    func testCustomStyleOverridesDefaults() {
        var style = AnnotationStyle()
        style.strokeColor = .red
        style.fillColor = .clear
        style.fontBold = false
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 50), style: style)
        XCTAssertEqual(bubble.style.strokeColor, .red)
        XCTAssertEqual(bubble.style.fillColor, .clear)
        XCTAssertFalse(bubble.style.fontBold)
    }
}
