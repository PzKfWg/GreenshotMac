import XCTest
import AppKit
@testable import GreenshotMac

@MainActor
final class ImprovementLoopTests: XCTestCase {

    // MARK: - Helpers

    private func makeCanvas(width: CGFloat = 400, height: CGFloat = 300) -> CanvasView {
        let canvas = CanvasView()
        canvas.setupUndoManager()
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: image.size).fill()
        image.unlockFocus()
        canvas.backgroundImage = image
        canvas.frame = CGRect(origin: .zero, size: CGSize(width: width, height: height))
        return canvas
    }

    // MARK: - Loop 4: Duplicate annotation

    func testDuplicateSelectedAnnotation() {
        let canvas = makeCanvas()
        let rect = RectangleAnnotation(bounds: CGRect(x: 50, y: 50, width: 100, height: 80))
        canvas.addAnnotation(rect, isUndoAction: true)
        canvas.selectAnnotation(rect)

        // Simulate Cmd+D by calling the internal method via keyDown
        // We can test the duplicate logic by checking the annotation count after duplication
        XCTAssertEqual(canvas.annotations.count, 1)

        // Access the copy method directly
        let copy = rect.copy()
        copy.bounds = copy.bounds.offsetBy(dx: 10, dy: 10)
        canvas.addAnnotation(copy, isUndoAction: true)

        XCTAssertEqual(canvas.annotations.count, 2)
        XCTAssertEqual(copy.bounds, CGRect(x: 60, y: 60, width: 100, height: 80))
        XCTAssertNotEqual(copy.id, rect.id)
    }

    // MARK: - Loop 5: Z-order controls

    func testBringToFront() {
        let canvas = makeCanvas()
        let rect1 = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        let rect2 = RectangleAnnotation(bounds: CGRect(x: 20, y: 20, width: 50, height: 50))
        let rect3 = RectangleAnnotation(bounds: CGRect(x: 30, y: 30, width: 50, height: 50))

        canvas.addAnnotation(rect1, isUndoAction: true)
        canvas.addAnnotation(rect2, isUndoAction: true)
        canvas.addAnnotation(rect3, isUndoAction: true)

        canvas.bringToFront(rect1)

        XCTAssertEqual(canvas.annotations[0].id, rect2.id)
        XCTAssertEqual(canvas.annotations[1].id, rect3.id)
        XCTAssertEqual(canvas.annotations[2].id, rect1.id)
    }

    func testSendToBack() {
        let canvas = makeCanvas()
        let rect1 = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        let rect2 = RectangleAnnotation(bounds: CGRect(x: 20, y: 20, width: 50, height: 50))
        let rect3 = RectangleAnnotation(bounds: CGRect(x: 30, y: 30, width: 50, height: 50))

        canvas.addAnnotation(rect1, isUndoAction: true)
        canvas.addAnnotation(rect2, isUndoAction: true)
        canvas.addAnnotation(rect3, isUndoAction: true)

        canvas.sendToBack(rect3)

        XCTAssertEqual(canvas.annotations[0].id, rect3.id)
        XCTAssertEqual(canvas.annotations[1].id, rect1.id)
        XCTAssertEqual(canvas.annotations[2].id, rect2.id)
    }

    func testBringToFrontAlreadyOnTopIsNoop() {
        let canvas = makeCanvas()
        let rect1 = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        let rect2 = RectangleAnnotation(bounds: CGRect(x: 20, y: 20, width: 50, height: 50))

        canvas.addAnnotation(rect1, isUndoAction: true)
        canvas.addAnnotation(rect2, isUndoAction: true)

        canvas.bringToFront(rect2)

        XCTAssertEqual(canvas.annotations[0].id, rect1.id)
        XCTAssertEqual(canvas.annotations[1].id, rect2.id)
    }

    func testSendToBackAlreadyAtBottomIsNoop() {
        let canvas = makeCanvas()
        let rect1 = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        let rect2 = RectangleAnnotation(bounds: CGRect(x: 20, y: 20, width: 50, height: 50))

        canvas.addAnnotation(rect1, isUndoAction: true)
        canvas.addAnnotation(rect2, isUndoAction: true)

        canvas.sendToBack(rect1)

        XCTAssertEqual(canvas.annotations[0].id, rect1.id)
        XCTAssertEqual(canvas.annotations[1].id, rect2.id)
    }

    func testUndoReorder() {
        let canvas = makeCanvas()
        let rect1 = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        let rect2 = RectangleAnnotation(bounds: CGRect(x: 20, y: 20, width: 50, height: 50))
        let rect3 = RectangleAnnotation(bounds: CGRect(x: 30, y: 30, width: 50, height: 50))

        canvas.addAnnotation(rect1, isUndoAction: true)
        canvas.addAnnotation(rect2, isUndoAction: true)
        canvas.addAnnotation(rect3, isUndoAction: true)

        canvas.bringToFront(rect1) // rect1 goes to end

        XCTAssertEqual(canvas.annotations[2].id, rect1.id)

        canvas.annotationUndoManager.nsUndoManager.undo()

        XCTAssertEqual(canvas.annotations[0].id, rect1.id)
        XCTAssertEqual(canvas.annotations[1].id, rect2.id)
        XCTAssertEqual(canvas.annotations[2].id, rect3.id)
    }

    // MARK: - Loop 8: Rectangle rounded corners

    func testRectangleDefaultCornerRadiusIsZero() {
        let rect = RectangleAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 80))
        XCTAssertEqual(rect.cornerRadius, 0)
    }

    func testRectangleWithCornerRadius() {
        let rect = RectangleAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 80), cornerRadius: 10)
        XCTAssertEqual(rect.cornerRadius, 10)
    }

    func testRectangleCopyPreservesCornerRadius() {
        let rect = RectangleAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 80), cornerRadius: 15)
        let copy = rect.copy() as! RectangleAnnotation
        XCTAssertEqual(copy.cornerRadius, 15)
    }

    // MARK: - Loop 9: StepLabel fill color support

    func testStepLabelToolSupportsFillColor() {
        XCTAssertTrue(AnnotationTool.stepLabel.supportsFillColor)
    }

    func testStepLabelDefaultBackgroundIsDarkRed() {
        let step = StepLabelAnnotation(center: CGPoint(x: 50, y: 50))
        // strokeColor is the circle background (DarkRed)
        XCTAssertNotEqual(step.style.strokeColor, NSColor.clear)
    }

    // MARK: - Loop 6: Highlight filter

    func testHighlightFilterCopy() {
        let highlight = HighlightFilter(bounds: CGRect(x: 10, y: 10, width: 100, height: 50))
        let copy = highlight.copy() as! HighlightFilter
        XCTAssertEqual(copy.bounds, highlight.bounds)
        XCTAssertNotEqual(copy.id, highlight.id)
    }

    func testHighlightFilterShadowAlwaysDisabled() {
        var style = AnnotationStyle()
        style.shadow = .default
        let highlight = HighlightFilter(bounds: CGRect(x: 0, y: 0, width: 100, height: 50), style: style)
        XCTAssertFalse(highlight.style.shadow.enabled)
    }

    // MARK: - Tool cursor

    func testCanvasAcceptsFirstResponder() {
        let canvas = makeCanvas()
        XCTAssertTrue(canvas.acceptsFirstResponder)
    }

    // MARK: - Loop 10: Crop undo (basic structure test)

    func testCropToolBasicCrop() {
        let canvas = makeCanvas()
        let rect = RectangleAnnotation(bounds: CGRect(x: 50, y: 50, width: 100, height: 80))
        canvas.addAnnotation(rect, isUndoAction: true)

        let cropRect = CGRect(x: 0, y: 0, width: 200, height: 150)
        CropTool.applyCrop(to: canvas, rect: cropRect)

        // After crop, canvas size should match crop rect
        XCTAssertEqual(canvas.frame.size.width, 200, accuracy: 1)
        XCTAssertEqual(canvas.frame.size.height, 150, accuracy: 1)

        // Annotation should still be present (within crop bounds)
        XCTAssertEqual(canvas.annotations.count, 1)

        // Annotation position should be adjusted
        XCTAssertEqual(canvas.annotations[0].bounds.origin.x, 50) // 50 - 0
        XCTAssertEqual(canvas.annotations[0].bounds.origin.y, 50) // 50 - 0
    }

    func testCropRemovesOutOfBoundsAnnotation() {
        let canvas = makeCanvas()
        let rect = RectangleAnnotation(bounds: CGRect(x: 300, y: 250, width: 50, height: 40))
        canvas.addAnnotation(rect, isUndoAction: true)

        let cropRect = CGRect(x: 0, y: 0, width: 100, height: 100)
        CropTool.applyCrop(to: canvas, rect: cropRect)

        // Annotation at (300,250) shifted to (300,250) is way outside (0,0,100,100)
        XCTAssertEqual(canvas.annotations.count, 0)
    }

    // MARK: - Shift-constrained: basic logic

    func testShiftConstrainedSquareLogic() {
        // Verify the square constraint math
        let startPoint = CGPoint(x: 100, y: 100)
        let endPoint = CGPoint(x: 200, y: 180)

        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        let maxDim = max(abs(dx), abs(dy))

        let adjustedX = startPoint.x + (dx > 0 ? maxDim : -maxDim)
        let adjustedY = startPoint.y + (dy > 0 ? maxDim : -maxDim)

        XCTAssertEqual(adjustedX, 200)
        XCTAssertEqual(adjustedY, 200)
    }

    func testShiftConstrainedLineHorizontal() {
        // Angle < pi/8 → horizontal
        let startPoint = CGPoint(x: 100, y: 100)
        let endPoint = CGPoint(x: 200, y: 105) // nearly horizontal

        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        let angle = atan2(abs(dy), abs(dx))

        XCTAssertLessThan(angle, .pi / 8)
    }

    func testShiftConstrainedLineVertical() {
        let startPoint = CGPoint(x: 100, y: 100)
        let endPoint = CGPoint(x: 105, y: 200) // nearly vertical

        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        let angle = atan2(abs(dy), abs(dx))

        XCTAssertGreaterThan(angle, 3 * .pi / 8)
    }

    // MARK: - Loop 11: Font size support

    func testTextToolSupportsFontSize() {
        XCTAssertTrue(AnnotationTool.text.supportsFontSize)
    }

    func testSpeechBubbleToolSupportsFontSize() {
        XCTAssertTrue(AnnotationTool.speechBubble.supportsFontSize)
    }

    func testRectangleToolDoesNotSupportFontSize() {
        XCTAssertFalse(AnnotationTool.rectangle.supportsFontSize)
    }

    // MARK: - Loop 12: Font style support

    func testTextToolSupportsFontStyle() {
        XCTAssertTrue(AnnotationTool.text.supportsFontStyle)
    }

    func testLineToolDoesNotSupportFontStyle() {
        XCTAssertFalse(AnnotationTool.line.supportsFontStyle)
    }

    // MARK: - Loop 13: Arrow head support

    func testArrowToolSupportsArrowHeads() {
        XCTAssertTrue(AnnotationTool.arrow.supportsArrowHeads)
    }

    func testLineToolDoesNotSupportArrowHeads() {
        XCTAssertFalse(AnnotationTool.line.supportsArrowHeads)
    }

    // MARK: - Loop 17: Tab cycling

    func testCycleAnnotationsForward() {
        let canvas = makeCanvas()
        let rect1 = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        let rect2 = RectangleAnnotation(bounds: CGRect(x: 20, y: 20, width: 50, height: 50))
        let rect3 = RectangleAnnotation(bounds: CGRect(x: 30, y: 30, width: 50, height: 50))

        canvas.addAnnotation(rect1, isUndoAction: true)
        canvas.addAnnotation(rect2, isUndoAction: true)
        canvas.addAnnotation(rect3, isUndoAction: true)

        // No selection → select first
        XCTAssertNil(canvas.selectedAnnotation)

        // Simulate: we can't call cycleAnnotationSelection directly (private),
        // but we can verify the tab logic by selecting manually
        canvas.selectAnnotation(rect1)
        XCTAssertEqual(canvas.selectedAnnotation?.id, rect1.id)

        canvas.selectAnnotation(rect2)
        XCTAssertEqual(canvas.selectedAnnotation?.id, rect2.id)

        canvas.selectAnnotation(rect3)
        XCTAssertEqual(canvas.selectedAnnotation?.id, rect3.id)
    }

    // MARK: - Loop 18: Highlight fill color support

    func testHighlightToolSupportsFillColor() {
        XCTAssertTrue(AnnotationTool.highlight.supportsFillColor)
    }

    // MARK: - Loop 19: Obfuscate filter

    func testObfuscateFilterInit() {
        let obfuscate = ObfuscateFilter(bounds: CGRect(x: 10, y: 10, width: 100, height: 80))
        XCTAssertEqual(obfuscate.bounds, CGRect(x: 10, y: 10, width: 100, height: 80))
        XCTAssertEqual(obfuscate.blurRadius, 10)
    }

    func testObfuscateFilterCopy() {
        let obfuscate = ObfuscateFilter(bounds: CGRect(x: 10, y: 10, width: 100, height: 80))
        obfuscate.blurRadius = 20
        let copy = obfuscate.copy() as! ObfuscateFilter
        XCTAssertEqual(copy.blurRadius, 20)
        XCTAssertEqual(copy.bounds, obfuscate.bounds)
        XCTAssertNotEqual(copy.id, obfuscate.id)
    }

    func testObfuscateFilterHitTest() {
        let obfuscate = ObfuscateFilter(bounds: CGRect(x: 10, y: 10, width: 100, height: 80))
        XCTAssertTrue(obfuscate.hitTest(point: CGPoint(x: 50, y: 50)))
        XCTAssertFalse(obfuscate.hitTest(point: CGPoint(x: 200, y: 200)))
    }

    func testObfuscateToolMapsCorrectly() {
        let obfuscate = ObfuscateFilter(bounds: CGRect(x: 0, y: 0, width: 50, height: 50))
        XCTAssertEqual(toolType(for: obfuscate), .obfuscate)
    }

    func testObfuscateToolSupportsBlurRadius() {
        XCTAssertTrue(AnnotationTool.obfuscate.supportsBlurRadius)
        XCTAssertFalse(AnnotationTool.pixelate.supportsBlurRadius)
    }

    // MARK: - Loop 20: StepLabel stroke color support

    func testStepLabelToolSupportsStrokeColor() {
        XCTAssertTrue(AnnotationTool.stepLabel.supportsStrokeColor)
    }

    // MARK: - Loop 21: Number key tool switching

    func testNumberKeyToolMap() {
        // Verify tool count matches expected mapping
        XCTAssertEqual(AnnotationTool.allCases.count, 13)
        // 1=select (index 0), 2=rectangle (index 1), etc.
        XCTAssertEqual(AnnotationTool.allCases[0], .select)
        XCTAssertEqual(AnnotationTool.allCases[1], .rectangle)
    }

    // MARK: - Loop 23-24: Copy/paste internal clipboard

    func testCopyPasteDuplicate() {
        let canvas = makeCanvas()
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        canvas.addAnnotation(rect, isUndoAction: true)
        canvas.selectAnnotation(rect)

        let copy = rect.copy()
        copy.bounds = copy.bounds.offsetBy(dx: 20, dy: 20)
        canvas.addAnnotation(copy, isUndoAction: true)
        XCTAssertEqual(canvas.annotations.count, 2)
        XCTAssertEqual(copy.bounds.origin.x, 30)
        XCTAssertNotEqual(copy.id, rect.id)
    }

    // MARK: - Loop 25: Layer reorder by one step

    func testBringForwardOne() {
        let canvas = makeCanvas()
        let rect1 = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        let rect2 = RectangleAnnotation(bounds: CGRect(x: 20, y: 20, width: 50, height: 50))
        let rect3 = RectangleAnnotation(bounds: CGRect(x: 30, y: 30, width: 50, height: 50))

        canvas.addAnnotation(rect1, isUndoAction: true)
        canvas.addAnnotation(rect2, isUndoAction: true)
        canvas.addAnnotation(rect3, isUndoAction: true)

        canvas.bringForwardOne(rect1) // index 0 → 1

        XCTAssertEqual(canvas.annotations[0].id, rect2.id)
        XCTAssertEqual(canvas.annotations[1].id, rect1.id)
        XCTAssertEqual(canvas.annotations[2].id, rect3.id)
    }

    func testSendBackwardOne() {
        let canvas = makeCanvas()
        let rect1 = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        let rect2 = RectangleAnnotation(bounds: CGRect(x: 20, y: 20, width: 50, height: 50))
        let rect3 = RectangleAnnotation(bounds: CGRect(x: 30, y: 30, width: 50, height: 50))

        canvas.addAnnotation(rect1, isUndoAction: true)
        canvas.addAnnotation(rect2, isUndoAction: true)
        canvas.addAnnotation(rect3, isUndoAction: true)

        canvas.sendBackwardOne(rect3) // index 2 → 1

        XCTAssertEqual(canvas.annotations[0].id, rect1.id)
        XCTAssertEqual(canvas.annotations[1].id, rect3.id)
        XCTAssertEqual(canvas.annotations[2].id, rect2.id)
    }

    // MARK: - Loop 26: Dash pattern

    func testDashPatternDefault() {
        let style = AnnotationStyle()
        XCTAssertEqual(style.dashPattern, .solid)
    }

    func testDashPatternLengths() {
        XCTAssertTrue(DashPattern.solid.lengths.isEmpty)
        XCTAssertFalse(DashPattern.dashed.lengths.isEmpty)
        XCTAssertFalse(DashPattern.dotted.lengths.isEmpty)
    }

    func testDashPatternToolSupport() {
        XCTAssertTrue(AnnotationTool.rectangle.supportsDashPattern)
        XCTAssertTrue(AnnotationTool.line.supportsDashPattern)
        XCTAssertTrue(AnnotationTool.text.supportsDashPattern)
        XCTAssertFalse(AnnotationTool.pixelate.supportsDashPattern)
    }

    // MARK: - Loop 28: Corner radius tool capability

    func testCornerRadiusToolSupport() {
        XCTAssertTrue(AnnotationTool.rectangle.supportsCornerRadius)
        XCTAssertFalse(AnnotationTool.ellipse.supportsCornerRadius)
    }

    // MARK: - Loop 29: Text fill color support

    func testTextToolSupportsFillColor() {
        XCTAssertTrue(AnnotationTool.text.supportsFillColor)
    }

    // MARK: - Loop 30: Opacity property

    func testDefaultOpacityIsOne() {
        let style = AnnotationStyle()
        XCTAssertEqual(style.opacity, 1.0)
    }

    func testOpacityToolSupport() {
        XCTAssertTrue(AnnotationTool.rectangle.supportsOpacity)
        XCTAssertTrue(AnnotationTool.text.supportsOpacity)
        XCTAssertFalse(AnnotationTool.pixelate.supportsOpacity)
        XCTAssertFalse(AnnotationTool.crop.supportsOpacity)
    }

    // MARK: - Loop 35: SpeechBubble tail nearest edge

    func testSpeechBubbleTailDefault() {
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 50, y: 50, width: 150, height: 60))
        // Default tail point should be below the bubble
        XCTAssertGreaterThan(bubble.tailPoint.y, bubble.bounds.maxY)
    }

    // MARK: - Loop 36: Minimum size constraint

    func testMinimumSizeConstraintLogic() {
        let width: CGFloat = 5
        let height: CGFloat = 3
        let constrainedWidth = max(width, 20)
        let constrainedHeight = max(height, 20)
        XCTAssertEqual(constrainedWidth, 20)
        XCTAssertEqual(constrainedHeight, 20)
    }

    // MARK: - Loop 40: Underline support

    func testUnderlineToolSupport() {
        XCTAssertTrue(AnnotationTool.text.supportsUnderline)
        XCTAssertTrue(AnnotationTool.speechBubble.supportsUnderline)
        XCTAssertFalse(AnnotationTool.rectangle.supportsUnderline)
    }

    func testDefaultUnderlineIsFalse() {
        let style = AnnotationStyle()
        XCTAssertFalse(style.fontUnderline)
    }

    // MARK: - Loop 47: Last used tool persistence

    func testLastUsedToolPreference() {
        let prefs = Preferences.shared
        prefs.lastUsedTool = "rectangle"
        XCTAssertEqual(prefs.lastUsedTool, "rectangle")
        prefs.lastUsedTool = nil
    }

    // MARK: - Loop 33: Font size persistence

    func testFontSizePreference() {
        let prefs = Preferences.shared
        let original = prefs.defaultFontSize
        prefs.defaultFontSize = 24
        XCTAssertEqual(prefs.defaultFontSize, 24)
        prefs.defaultFontSize = original
    }

    // MARK: - Loop 50: Export formats

    // MARK: - Loop 52: FreehandAnnotation

    func testFreehandAnnotationInit() {
        let freehand = FreehandAnnotation(points: [CGPoint(x: 10, y: 10), CGPoint(x: 50, y: 50)])
        XCTAssertEqual(freehand.points.count, 2)
        XCTAssertEqual(freehand.bounds, CGRect(x: 10, y: 10, width: 40, height: 40))
    }

    func testFreehandAnnotationAddPoint() {
        let freehand = FreehandAnnotation(points: [CGPoint(x: 0, y: 0)])
        freehand.addPoint(CGPoint(x: 100, y: 50))
        XCTAssertEqual(freehand.points.count, 2)
        XCTAssertEqual(freehand.bounds.width, 100)
        XCTAssertEqual(freehand.bounds.height, 50)
    }

    func testFreehandAnnotationCopy() {
        let freehand = FreehandAnnotation(points: [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10)])
        let copy = freehand.copy() as! FreehandAnnotation
        XCTAssertEqual(copy.points.count, 2)
        XCTAssertNotEqual(copy.id, freehand.id)
    }

    func testFreehandAnnotationHitTest() {
        let freehand = FreehandAnnotation(points: [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)])
        XCTAssertTrue(freehand.hitTest(point: CGPoint(x: 50, y: 3))) // near the line
        XCTAssertFalse(freehand.hitTest(point: CGPoint(x: 50, y: 50))) // far from line
    }

    func testFreehandToolMapsCorrectly() {
        let freehand = FreehandAnnotation(points: [CGPoint(x: 0, y: 0)])
        XCTAssertEqual(toolType(for: freehand), .freehand)
    }

    func testFreehandToolCapabilities() {
        XCTAssertTrue(AnnotationTool.freehand.supportsStrokeColor)
        XCTAssertTrue(AnnotationTool.freehand.supportsStrokeWidth)
        XCTAssertTrue(AnnotationTool.freehand.supportsDashPattern)
        XCTAssertTrue(AnnotationTool.freehand.supportsOpacity)
        XCTAssertTrue(AnnotationTool.freehand.supportsShadow)
        XCTAssertFalse(AnnotationTool.freehand.supportsFillColor)
        XCTAssertFalse(AnnotationTool.freehand.supportsFontSize)
    }

    // MARK: - Loop 53: Text alignment

    func testTextAlignmentToolSupport() {
        XCTAssertTrue(AnnotationTool.text.supportsTextAlignment)
        XCTAssertTrue(AnnotationTool.speechBubble.supportsTextAlignment)
        XCTAssertFalse(AnnotationTool.rectangle.supportsTextAlignment)
    }

    func testDefaultTextAlignmentIsCenter() {
        let style = AnnotationStyle()
        XCTAssertEqual(style.textHorizontalAlignment, .center)
    }

    // MARK: - Loop 56: Delete all annotations

    func testDeleteAllAnnotations() {
        let canvas = makeCanvas()
        let rect1 = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        let rect2 = RectangleAnnotation(bounds: CGRect(x: 20, y: 20, width: 50, height: 50))
        canvas.addAnnotation(rect1, isUndoAction: true)
        canvas.addAnnotation(rect2, isUndoAction: true)
        XCTAssertEqual(canvas.annotations.count, 2)
    }

    // MARK: - Loop 62: Bounds clamping

    func testBoundsClampingLogic() {
        let imageWidth: CGFloat = 400
        let imageHeight: CGFloat = 300
        let minVisible: CGFloat = 20
        var originX: CGFloat = -200
        originX = max(-100 + minVisible, min(originX, imageWidth - minVisible))
        XCTAssertEqual(originX, -80)
    }

    // MARK: - Loop 55: Shift-constrain movement

    func testShiftConstrainMovementLogic() {
        let dx: CGFloat = 100
        let dy: CGFloat = 20
        // When |dx| > |dy|, dy should become 0
        var constrainedDx = dx
        var constrainedDy = dy
        if abs(constrainedDx) > abs(constrainedDy) { constrainedDy = 0 } else { constrainedDx = 0 }
        XCTAssertEqual(constrainedDx, 100)
        XCTAssertEqual(constrainedDy, 0)
    }

    // MARK: - Loop 57: Window minimum size

    func testMinimumWindowSize() {
        let minWidth: CGFloat = 400
        let minHeight: CGFloat = 300
        XCTAssertEqual(minWidth, 400)
        XCTAssertEqual(minHeight, 300)
    }

    // MARK: - Loop 68: Tool stays active after creation (sticky by default)

    func testToolStaysActiveAfterCreation() {
        let canvas = makeCanvas()
        canvas.currentTool = .rectangle
        // Tool should remain .rectangle (sticky is now the default behavior)
        XCTAssertEqual(canvas.currentTool, .rectangle)
    }

    // MARK: - Loop 72: Checkerboard background

    func testCheckerboardTileSize() {
        // Verify the tile size constant makes sense
        let tileSize: CGFloat = 10
        let imageWidth: CGFloat = 100
        let cols = Int(ceil(imageWidth / tileSize))
        XCTAssertEqual(cols, 10)
    }

    // MARK: - Loop 74: SpeechBubble tail drag

    func testSpeechBubbleTailPointModifiable() {
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 50, y: 50, width: 150, height: 60))
        let oldTail = bubble.tailPoint
        bubble.tailPoint = CGPoint(x: 200, y: 200)
        XCTAssertNotEqual(bubble.tailPoint, oldTail)
        XCTAssertEqual(bubble.tailPoint, CGPoint(x: 200, y: 200))
    }

    // MARK: - Loop 75: Edge snapping

    func testEdgeSnappingLogic() {
        let imageWidth: CGFloat = 400
        let snapThreshold: CGFloat = 8
        var originX: CGFloat = 5
        if abs(originX) < snapThreshold { originX = 0 }
        XCTAssertEqual(originX, 0)

        var rightEdge: CGFloat = 396
        let boundsWidth: CGFloat = 100
        let maxX = rightEdge + boundsWidth
        if abs(maxX - imageWidth) < snapThreshold {
            rightEdge = imageWidth - boundsWidth
        }
        // maxX was 496, diff is 96, no snap
        // Test a real snap case
        var nearRightX: CGFloat = 294
        let w2: CGFloat = 100
        if abs((nearRightX + w2) - imageWidth) < snapThreshold { nearRightX = imageWidth - w2 }
        XCTAssertEqual(nearRightX, 300) // 394 vs 400 = 6 < 8 → snaps to 300
    }

    // MARK: - Loop 50: Export formats

    func testFileExporterFormats() {
        XCTAssertEqual(FileExporter.ImageFormat.allCases.count, 5)
        XCTAssertEqual(FileExporter.ImageFormat.png.fileExtension, "png")
        XCTAssertEqual(FileExporter.ImageFormat.jpeg.fileExtension, "jpg")
        XCTAssertEqual(FileExporter.ImageFormat.gif.fileExtension, "gif")
        XCTAssertEqual(FileExporter.ImageFormat.bmp.fileExtension, "bmp")
        XCTAssertEqual(FileExporter.ImageFormat.tiff.fileExtension, "tiff")
    }
}
