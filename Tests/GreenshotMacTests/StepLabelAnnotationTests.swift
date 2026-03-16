import XCTest
import AppKit
@testable import GreenshotMac

@MainActor
final class StepLabelAnnotationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        StepLabelAnnotation.resetCounter()
    }

    func testAutoIncrementStepNumbers() {
        let step1 = StepLabelAnnotation(center: CGPoint(x: 50, y: 50))
        let step2 = StepLabelAnnotation(center: CGPoint(x: 100, y: 100))
        let step3 = StepLabelAnnotation(center: CGPoint(x: 150, y: 150))
        XCTAssertEqual(step1.stepNumber, 1)
        XCTAssertEqual(step2.stepNumber, 2)
        XCTAssertEqual(step3.stepNumber, 3)
    }

    func testResetCounterResetsToOne() {
        _ = StepLabelAnnotation(center: CGPoint(x: 50, y: 50))
        _ = StepLabelAnnotation(center: CGPoint(x: 100, y: 100))
        StepLabelAnnotation.resetCounter()
        let step = StepLabelAnnotation(center: CGPoint(x: 150, y: 150))
        XCTAssertEqual(step.stepNumber, 1)
    }

    func testHitTestInsideCircle() {
        let step = StepLabelAnnotation(center: CGPoint(x: 50, y: 50))
        XCTAssertTrue(step.hitTest(point: CGPoint(x: 50, y: 50)))
        XCTAssertTrue(step.hitTest(point: CGPoint(x: 55, y: 55)))
    }

    func testHitTestOutsideCircle() {
        let step = StepLabelAnnotation(center: CGPoint(x: 50, y: 50))
        XCTAssertFalse(step.hitTest(point: CGPoint(x: 100, y: 100)))
        XCTAssertFalse(step.hitTest(point: CGPoint(x: 200, y: 200)))
    }

    func testCopyPreservesStepNumber() {
        let original = StepLabelAnnotation(center: CGPoint(x: 50, y: 50))
        let copy = original.copy()
        XCTAssertEqual(copy.bounds, original.bounds)
        XCTAssertNotEqual(copy.id, original.id)
        let copiedStep = copy as! StepLabelAnnotation
        XCTAssertEqual(copiedStep.stepNumber, original.stepNumber)
    }

    func testBoundsCenteredOnPoint() {
        let center = CGPoint(x: 80, y: 120)
        let step = StepLabelAnnotation(center: center)
        XCTAssertEqual(step.bounds.midX, center.x, accuracy: 0.01)
        XCTAssertEqual(step.bounds.midY, center.y, accuracy: 0.01)
        XCTAssertEqual(step.bounds.width, 30)
        XCTAssertEqual(step.bounds.height, 30)
    }

    func testSetCounterToCustomStart() {
        StepLabelAnnotation.setCounter(to: 5)
        let step1 = StepLabelAnnotation(center: CGPoint(x: 50, y: 50))
        let step2 = StepLabelAnnotation(center: CGPoint(x: 100, y: 100))
        XCTAssertEqual(step1.stepNumber, 5)
        XCTAssertEqual(step2.stepNumber, 6)
    }

    func testSetCounterMinimumIsOne() {
        StepLabelAnnotation.setCounter(to: 0)
        XCTAssertEqual(StepLabelAnnotation.currentCounter, 1)
        StepLabelAnnotation.setCounter(to: -5)
        XCTAssertEqual(StepLabelAnnotation.currentCounter, 1)
    }

    func testCurrentCounterReturnsNextValue() {
        XCTAssertEqual(StepLabelAnnotation.currentCounter, 1)
        _ = StepLabelAnnotation(center: CGPoint(x: 50, y: 50))
        XCTAssertEqual(StepLabelAnnotation.currentCounter, 2)
    }

    func testDefaultStyleValues() {
        let step = StepLabelAnnotation(center: CGPoint(x: 50, y: 50))
        // strokeColor = circle background (DarkRed)
        XCTAssertEqual(step.style.strokeColor, NSColor(red: 0.55, green: 0, blue: 0, alpha: 1))
        // fillColor = number text color (white)
        XCTAssertEqual(step.style.fillColor, .white)
        // No shadow
        XCTAssertEqual(step.style.shadow, .none)
    }

    func testCustomFillColorUsedForNumber() {
        var customStyle = StepLabelAnnotation.defaultStyle
        customStyle.fillColor = .blue
        let step = StepLabelAnnotation(center: CGPoint(x: 50, y: 50), style: customStyle)
        XCTAssertEqual(step.style.fillColor, .blue)
    }
}
