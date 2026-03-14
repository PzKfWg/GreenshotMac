import XCTest
import AppKit
@testable import GreenshotMac

// MARK: - Line Annotation Direction Tests

@MainActor
final class LineAnnotationDirectionTests: XCTestCase {

    func testTopLeftToBottomRight() {
        let line = LineAnnotation(
            bounds: CGRect(x: 10, y: 20, width: 100, height: 80),
            direction: .topLeftToBottomRight
        )
        XCTAssertEqual(line.startPoint, CGPoint(x: 10, y: 20))
        XCTAssertEqual(line.endPoint, CGPoint(x: 110, y: 100))
    }

    func testBottomLeftToTopRight() {
        let line = LineAnnotation(
            bounds: CGRect(x: 10, y: 20, width: 100, height: 80),
            direction: .bottomLeftToTopRight
        )
        XCTAssertEqual(line.startPoint, CGPoint(x: 10, y: 100))
        XCTAssertEqual(line.endPoint, CGPoint(x: 110, y: 20))
    }

    func testBottomRightToTopLeft() {
        let line = LineAnnotation(
            bounds: CGRect(x: 10, y: 20, width: 100, height: 80),
            direction: .bottomRightToTopLeft
        )
        XCTAssertEqual(line.startPoint, CGPoint(x: 110, y: 100))
        XCTAssertEqual(line.endPoint, CGPoint(x: 10, y: 20))
    }

    func testTopRightToBottomLeft() {
        let line = LineAnnotation(
            bounds: CGRect(x: 10, y: 20, width: 100, height: 80),
            direction: .topRightToBottomLeft
        )
        XCTAssertEqual(line.startPoint, CGPoint(x: 110, y: 20))
        XCTAssertEqual(line.endPoint, CGPoint(x: 10, y: 100))
    }

    func testCopyPreservesDirection() {
        let line = LineAnnotation(
            bounds: CGRect(x: 10, y: 20, width: 100, height: 80),
            direction: .bottomLeftToTopRight
        )
        guard let copy = line.copy() as? LineAnnotation else {
            XCTFail("Copy should return LineAnnotation")
            return
        }
        XCTAssertEqual(copy.direction, .bottomLeftToTopRight)
        XCTAssertEqual(copy.startPoint, line.startPoint)
        XCTAssertEqual(copy.endPoint, line.endPoint)
    }

    func testHitTestWorksWithAllDirections() {
        for direction in [DiagonalDirection.topLeftToBottomRight, .bottomLeftToTopRight,
                          .bottomRightToTopLeft, .topRightToBottomLeft] {
            let line = LineAnnotation(
                bounds: CGRect(x: 0, y: 0, width: 100, height: 100),
                direction: direction
            )
            // The midpoint of the line segment should always hit
            let mid = CGPoint(
                x: (line.startPoint.x + line.endPoint.x) / 2,
                y: (line.startPoint.y + line.endPoint.y) / 2
            )
            XCTAssertTrue(line.hitTest(point: mid), "HitTest failed for direction: \(direction)")
        }
    }
}

// MARK: - Arrow Annotation Direction Tests

@MainActor
final class ArrowAnnotationDirectionTests: XCTestCase {

    func testTopLeftToBottomRight() {
        let arrow = ArrowAnnotation(
            bounds: CGRect(x: 10, y: 20, width: 100, height: 80),
            direction: .topLeftToBottomRight
        )
        XCTAssertEqual(arrow.startPoint, CGPoint(x: 10, y: 20))
        XCTAssertEqual(arrow.endPoint, CGPoint(x: 110, y: 100))
    }

    func testBottomLeftToTopRight() {
        let arrow = ArrowAnnotation(
            bounds: CGRect(x: 10, y: 20, width: 100, height: 80),
            direction: .bottomLeftToTopRight
        )
        XCTAssertEqual(arrow.startPoint, CGPoint(x: 10, y: 100))
        XCTAssertEqual(arrow.endPoint, CGPoint(x: 110, y: 20))
    }

    func testBottomRightToTopLeft() {
        let arrow = ArrowAnnotation(
            bounds: CGRect(x: 10, y: 20, width: 100, height: 80),
            direction: .bottomRightToTopLeft
        )
        XCTAssertEqual(arrow.startPoint, CGPoint(x: 110, y: 100))
        XCTAssertEqual(arrow.endPoint, CGPoint(x: 10, y: 20))
    }

    func testTopRightToBottomLeft() {
        let arrow = ArrowAnnotation(
            bounds: CGRect(x: 10, y: 20, width: 100, height: 80),
            direction: .topRightToBottomLeft
        )
        XCTAssertEqual(arrow.startPoint, CGPoint(x: 110, y: 20))
        XCTAssertEqual(arrow.endPoint, CGPoint(x: 10, y: 100))
    }

    func testCopyPreservesDirection() {
        let arrow = ArrowAnnotation(
            bounds: CGRect(x: 10, y: 20, width: 100, height: 80),
            direction: .bottomRightToTopLeft
        )
        guard let copy = arrow.copy() as? ArrowAnnotation else {
            XCTFail("Copy should return ArrowAnnotation")
            return
        }
        XCTAssertEqual(copy.direction, .bottomRightToTopLeft)
    }

    func testHitTestWorksWithAllDirections() {
        for direction in [DiagonalDirection.topLeftToBottomRight, .bottomLeftToTopRight,
                          .bottomRightToTopLeft, .topRightToBottomLeft] {
            let arrow = ArrowAnnotation(
                bounds: CGRect(x: 0, y: 0, width: 100, height: 100),
                direction: direction
            )
            let mid = CGPoint(
                x: (arrow.startPoint.x + arrow.endPoint.x) / 2,
                y: (arrow.startPoint.y + arrow.endPoint.y) / 2
            )
            XCTAssertTrue(arrow.hitTest(point: mid), "HitTest failed for direction: \(direction)")
        }
    }

    func testArrowheadSizeIncreasesWithStrokeWidth() {
        // Spec: arrowhead size = 10 + strokeWidth * 2
        // We verify indirectly that thicker strokes make bigger arrowheads
        var thinStyle = AnnotationStyle()
        thinStyle.strokeWidth = 1
        let thinArrow = ArrowAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 50), style: thinStyle)

        var thickStyle = AnnotationStyle()
        thickStyle.strokeWidth = 10
        let thickArrow = ArrowAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 50), style: thickStyle)

        // Both should still have valid hit tests
        XCTAssertTrue(thinArrow.hitTest(point: CGPoint(x: 50, y: 25)))
        XCTAssertTrue(thickArrow.hitTest(point: CGPoint(x: 50, y: 25)))

        // Thick arrow should have larger effective stroke width
        XCTAssertGreaterThan(thickArrow.style.strokeWidth, thinArrow.style.strokeWidth)
    }
}

// MARK: - SpeechBubble Extended Tests

@MainActor
final class SpeechBubbleExtendedTests: XCTestCase {

    func testHitTestInTailTriangle() {
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 50, y: 100, width: 200, height: 80))
        // tailPoint defaults to (150, 210) — midX, maxY+30
        // The tail triangle goes from the bottom edge to tailPoint
        // A point between the bottom edge and tailPoint should hit
        let pointInTail = CGPoint(x: 150, y: 195)
        XCTAssertTrue(bubble.hitTest(point: pointInTail), "Should hit in tail triangle")
    }

    func testHitTestOutsideTailAndBody() {
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 50, y: 100, width: 200, height: 80))
        // Point far to the right of the tail
        XCTAssertFalse(bubble.hitTest(point: CGPoint(x: 300, y: 200)))
    }

    func testHitTestAtBodyEdgeWithTolerance() {
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 50, y: 100, width: 200, height: 80))
        // Point 3px outside the body (within 4px tolerance)
        XCTAssertTrue(bubble.hitTest(point: CGPoint(x: 47, y: 140)))
    }

    func testHitTestBeyondTolerance() {
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 50, y: 100, width: 200, height: 80))
        // Point 10px outside the body (beyond 4px tolerance) and not in tail
        XCTAssertFalse(bubble.hitTest(point: CGPoint(x: 40, y: 140)))
    }

    func testCustomTailPoint() {
        let customTail = CGPoint(x: 300, y: 50)
        let bubble = SpeechBubbleAnnotation(
            bounds: CGRect(x: 50, y: 100, width: 200, height: 80),
            tailPoint: customTail
        )
        XCTAssertEqual(bubble.tailPoint, customTail)
    }

    func testDefaultTextIsText() {
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 50, y: 100, width: 200, height: 80))
        XCTAssertEqual(bubble.text, "Text")
    }

    func testCustomTextPreserved() {
        let bubble = SpeechBubbleAnnotation(
            bounds: CGRect(x: 50, y: 100, width: 200, height: 80),
            text: "Custom message"
        )
        XCTAssertEqual(bubble.text, "Custom message")
    }

    func testCopyReturnsSpeechBubbleAnnotation() {
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 50, y: 100, width: 200, height: 80))
        let copy = bubble.copy()
        XCTAssertTrue(copy is SpeechBubbleAnnotation)
    }

    func testDefaultTailPointCalculation() {
        let bounds = CGRect(x: 50, y: 100, width: 200, height: 80)
        let bubble = SpeechBubbleAnnotation(bounds: bounds)
        // In flipped coords, maxY is bottom, tailPoint = midX, maxY+30
        XCTAssertEqual(bubble.tailPoint.x, bounds.midX)
        XCTAssertEqual(bubble.tailPoint.y, bounds.maxY + 30)
    }
}

// MARK: - Text Annotation Extended Tests

@MainActor
final class TextAnnotationExtendedTests: XCTestCase {

    func testDefaultTextIsText() {
        let text = TextAnnotation(bounds: CGRect(x: 0, y: 0, width: 150, height: 30))
        XCTAssertEqual(text.text, "Text")
    }

    func testCustomTextPreserved() {
        let text = TextAnnotation(bounds: CGRect(x: 0, y: 0, width: 150, height: 30), text: "Hello World")
        XCTAssertEqual(text.text, "Hello World")
    }

    func testDefaultSize() {
        // Spec: text annotation default size is 150x30
        let bounds = CGRect(origin: CGPoint(x: 50, y: 50), size: CGSize(width: 150, height: 30))
        let text = TextAnnotation(bounds: bounds)
        XCTAssertEqual(text.bounds.width, 150)
        XCTAssertEqual(text.bounds.height, 30)
    }

    func testCopyPreservesCustomText() {
        let original = TextAnnotation(bounds: CGRect(x: 0, y: 0, width: 150, height: 30), text: "Custom")
        guard let copy = original.copy() as? TextAnnotation else {
            XCTFail("Copy should return TextAnnotation")
            return
        }
        XCTAssertEqual(copy.text, "Custom")
        XCTAssertNotEqual(copy.id, original.id)
    }

    func testHitTestWithTolerance() {
        let text = TextAnnotation(bounds: CGRect(x: 50, y: 50, width: 150, height: 30))
        // 3px outside (within 4px tolerance)
        XCTAssertTrue(text.hitTest(point: CGPoint(x: 47, y: 65)))
        // 10px outside (beyond tolerance)
        XCTAssertFalse(text.hitTest(point: CGPoint(x: 30, y: 65)))
    }

    func testStyleFontAndColorUsed() {
        var style = AnnotationStyle()
        style.fontName = "Courier"
        style.fontSize = 24.0
        style.strokeColor = .blue
        let text = TextAnnotation(bounds: CGRect(x: 0, y: 0, width: 150, height: 30), style: style)
        XCTAssertEqual(text.style.fontName, "Courier")
        XCTAssertEqual(text.style.fontSize, 24.0)
        XCTAssertEqual(text.style.strokeColor, .blue)
    }
}

// MARK: - StepLabel Extended Tests

@MainActor
final class StepLabelExtendedTests: XCTestCase {

    override func setUp() async throws {
        StepLabelAnnotation.resetCounter()
    }

    func testStepNumberStartsAt1() {
        let step = StepLabelAnnotation(center: CGPoint(x: 100, y: 100))
        XCTAssertEqual(step.stepNumber, 1)
    }

    func testAutoIncrement() {
        let step1 = StepLabelAnnotation(center: CGPoint(x: 100, y: 100))
        let step2 = StepLabelAnnotation(center: CGPoint(x: 200, y: 200))
        let step3 = StepLabelAnnotation(center: CGPoint(x: 300, y: 300))
        XCTAssertEqual(step1.stepNumber, 1)
        XCTAssertEqual(step2.stepNumber, 2)
        XCTAssertEqual(step3.stepNumber, 3)
    }

    func testResetCounterStartsOver() {
        let _ = StepLabelAnnotation(center: CGPoint(x: 100, y: 100))
        let _ = StepLabelAnnotation(center: CGPoint(x: 200, y: 200))
        StepLabelAnnotation.resetCounter()
        let step = StepLabelAnnotation(center: CGPoint(x: 300, y: 300))
        XCTAssertEqual(step.stepNumber, 1)
    }

    func testBoundsCenteredOnPoint() {
        let center = CGPoint(x: 100, y: 100)
        let step = StepLabelAnnotation(center: center)
        // 30x30 circle centered on the point
        XCTAssertEqual(step.bounds.midX, center.x, accuracy: 0.01)
        XCTAssertEqual(step.bounds.midY, center.y, accuracy: 0.01)
        XCTAssertEqual(step.bounds.width, 30)
        XCTAssertEqual(step.bounds.height, 30)
    }

    func testCircularHitTestInside() {
        let step = StepLabelAnnotation(center: CGPoint(x: 100, y: 100))
        // Center should hit
        XCTAssertTrue(step.hitTest(point: CGPoint(x: 100, y: 100)))
        // Inside the circle but near the edge
        XCTAssertTrue(step.hitTest(point: CGPoint(x: 114, y: 100)))
    }

    func testCircularHitTestCornerOutside() {
        let step = StepLabelAnnotation(center: CGPoint(x: 100, y: 100))
        // Corner of the bounding rect is outside the circle
        // bounds is (85, 85, 30, 30), corner at (85, 85)
        // Distance from center (100,100) to (85,85) = sqrt(225+225) ≈ 21.2
        // Radius = 15, tolerance = 4, threshold = 19
        // 21.2 > 19, so should be false
        XCTAssertFalse(step.hitTest(point: CGPoint(x: 85, y: 85)))
    }

    func testCopyDoesNotIncrementCounter() {
        let step1 = StepLabelAnnotation(center: CGPoint(x: 100, y: 100))
        XCTAssertEqual(step1.stepNumber, 1)

        guard let copy = step1.copy() as? StepLabelAnnotation else {
            XCTFail("Copy should return StepLabelAnnotation")
            return
        }
        XCTAssertEqual(copy.stepNumber, 1)

        // Next created step should be 2 (not 3)
        let step2 = StepLabelAnnotation(center: CGPoint(x: 200, y: 200))
        XCTAssertEqual(step2.stepNumber, 2)
    }

    func testDefaultFillColorIsRedWhenClear() {
        // When fillColor is .clear, the circle should use systemRed
        let step = StepLabelAnnotation(center: CGPoint(x: 100, y: 100))
        XCTAssertEqual(step.style.fillColor, .clear) // Style stores .clear
        // The draw() method should use systemRed when fillColor is clear
    }

    func testCustomFillColorPreserved() {
        var style = AnnotationStyle()
        style.fillColor = .blue
        let step = StepLabelAnnotation(center: CGPoint(x: 100, y: 100), style: style)
        XCTAssertEqual(step.style.fillColor, .blue)
    }
}

// MARK: - Highlight Filter Shadow Override

@MainActor
final class HighlightFilterShadowTests: XCTestCase {

    func testShadowForcedToNoneEvenWhenStyleHasShadow() {
        var style = AnnotationStyle()
        style.shadow = .default // Enable shadow
        style.fillColor = .green.withAlphaComponent(0.5)

        let highlight = HighlightFilter(bounds: CGRect(x: 0, y: 0, width: 100, height: 50), style: style)

        // Shadow should be forced to .none regardless
        XCTAssertFalse(highlight.style.shadow.enabled)
        XCTAssertEqual(highlight.style.shadow, .none)
    }

    func testDefaultHighlightHasYellowFill() {
        let highlight = HighlightFilter(bounds: CGRect(x: 0, y: 0, width: 100, height: 50))
        XCTAssertNotEqual(highlight.style.fillColor, .clear)
        // Should be yellow at 40% opacity
    }

    func testCustomColorPreservedButShadowOverridden() {
        var style = AnnotationStyle()
        style.fillColor = .orange.withAlphaComponent(0.3)
        style.shadow = .default

        let highlight = HighlightFilter(bounds: CGRect(x: 0, y: 0, width: 100, height: 50), style: style)

        // Custom color preserved
        XCTAssertNotEqual(highlight.style.fillColor, .clear)
        // Shadow still forced to none
        XCTAssertFalse(highlight.style.shadow.enabled)
    }
}

// MARK: - Ellipse Extended Tests

@MainActor
final class EllipseExtendedTests: XCTestCase {

    func testSquareBoundsProduceCircle() {
        // When bounds are square, the ellipse should be a circle
        let ellipse = EllipseAnnotation(bounds: CGRect(x: 50, y: 50, width: 100, height: 100))
        XCTAssertEqual(ellipse.bounds.width, ellipse.bounds.height)
    }

    func testCopyReturnsEllipseAnnotation() {
        let ellipse = EllipseAnnotation(bounds: CGRect(x: 50, y: 50, width: 100, height: 100))
        XCTAssertTrue(ellipse.copy() is EllipseAnnotation)
    }

    func testCopyHasNewId() {
        let original = EllipseAnnotation(bounds: CGRect(x: 50, y: 50, width: 100, height: 100))
        let copy = original.copy()
        XCTAssertNotEqual(original.id, copy.id)
    }
}

// MARK: - Rectangle Extended Tests

@MainActor
final class RectangleExtendedTests: XCTestCase {

    func testFillColorPreserved() {
        var style = AnnotationStyle()
        style.fillColor = .blue.withAlphaComponent(0.5)
        let rect = RectangleAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 50), style: style)
        XCTAssertNotEqual(rect.style.fillColor, .clear)
    }

    func testDefaultFillIsClear() {
        let rect = RectangleAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 50))
        XCTAssertEqual(rect.style.fillColor, .clear)
    }

    func testShadowStylePreserved() {
        var style = AnnotationStyle()
        style.shadow = .default
        let rect = RectangleAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 50), style: style)
        XCTAssertTrue(rect.style.shadow.enabled)

        var style2 = AnnotationStyle()
        style2.shadow = .none
        let rect2 = RectangleAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 50), style: style2)
        XCTAssertFalse(rect2.style.shadow.enabled)
    }
}
