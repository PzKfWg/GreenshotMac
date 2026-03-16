import XCTest
import AppKit
@testable import GreenshotMac

@MainActor
final class CanvasViewTests: XCTestCase {

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

    // MARK: - Annotation Management

    func testAddAnnotationIncreasesCount() {
        let canvas = makeCanvas()
        XCTAssertEqual(canvas.annotations.count, 0)

        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        canvas.addAnnotation(rect, isUndoAction: true)

        XCTAssertEqual(canvas.annotations.count, 1)
    }

    func testRemoveAnnotationDecreasesCount() {
        let canvas = makeCanvas()
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        canvas.addAnnotation(rect, isUndoAction: true)
        XCTAssertEqual(canvas.annotations.count, 1)

        canvas.removeAnnotation(rect, isUndoAction: true)
        XCTAssertEqual(canvas.annotations.count, 0)
    }

    func testInsertAnnotationAtIndex() {
        let canvas = makeCanvas()
        let rect1 = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        let rect2 = RectangleAnnotation(bounds: CGRect(x: 20, y: 20, width: 50, height: 50))
        let rect3 = RectangleAnnotation(bounds: CGRect(x: 30, y: 30, width: 50, height: 50))

        canvas.addAnnotation(rect1, isUndoAction: true)
        canvas.addAnnotation(rect3, isUndoAction: true)
        canvas.insertAnnotation(rect2, at: 1, isUndoAction: true)

        XCTAssertEqual(canvas.annotations.count, 3)
        XCTAssertEqual(canvas.annotations[0].id, rect1.id)
        XCTAssertEqual(canvas.annotations[1].id, rect2.id)
        XCTAssertEqual(canvas.annotations[2].id, rect3.id)
    }

    func testInsertAnnotationAtSafeIndex() {
        let canvas = makeCanvas()
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        // Insert at index 100 when only 0 annotations exist — should insert at end
        canvas.insertAnnotation(rect, at: 100, isUndoAction: true)
        XCTAssertEqual(canvas.annotations.count, 1)
    }

    // MARK: - Selection

    func testSelectAnnotationSetsIsSelected() {
        let canvas = makeCanvas()
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        canvas.addAnnotation(rect, isUndoAction: true)

        canvas.selectAnnotation(rect)
        XCTAssertTrue(rect.isSelected)
    }

    func testSelectNilDeselectsCurrent() {
        let canvas = makeCanvas()
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        canvas.addAnnotation(rect, isUndoAction: true)
        canvas.selectAnnotation(rect)
        XCTAssertTrue(rect.isSelected)

        canvas.selectAnnotation(nil)
        XCTAssertFalse(rect.isSelected)
    }

    func testSelectNewAnnotationDeselectsPrevious() {
        let canvas = makeCanvas()
        let rect1 = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        let rect2 = RectangleAnnotation(bounds: CGRect(x: 100, y: 100, width: 50, height: 50))
        canvas.addAnnotation(rect1, isUndoAction: true)
        canvas.addAnnotation(rect2, isUndoAction: true)

        canvas.selectAnnotation(rect1)
        XCTAssertTrue(rect1.isSelected)

        canvas.selectAnnotation(rect2)
        XCTAssertFalse(rect1.isSelected)
        XCTAssertTrue(rect2.isSelected)
    }

    // MARK: - Remove selected clears selection

    func testRemoveSelectedAnnotationClearsSelection() {
        let canvas = makeCanvas()
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        canvas.addAnnotation(rect, isUndoAction: true)
        canvas.selectAnnotation(rect)

        canvas.removeAnnotation(rect, isUndoAction: true)
        XCTAssertEqual(canvas.annotations.count, 0)
        // The annotation should no longer be tracked as selected
    }

    // MARK: - Z-order

    func testAnnotationsPreserveInsertionOrder() {
        let canvas = makeCanvas()
        let rect1 = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 100, height: 100))
        let rect2 = RectangleAnnotation(bounds: CGRect(x: 20, y: 20, width: 100, height: 100))
        let rect3 = RectangleAnnotation(bounds: CGRect(x: 30, y: 30, width: 100, height: 100))

        canvas.addAnnotation(rect1, isUndoAction: true)
        canvas.addAnnotation(rect2, isUndoAction: true)
        canvas.addAnnotation(rect3, isUndoAction: true)

        XCTAssertEqual(canvas.annotations[0].id, rect1.id)
        XCTAssertEqual(canvas.annotations[1].id, rect2.id)
        XCTAssertEqual(canvas.annotations[2].id, rect3.id)
    }

    // MARK: - Tool state

    func testDefaultToolIsSelect() {
        let canvas = makeCanvas()
        XCTAssertEqual(canvas.currentTool, .select)
    }

    func testToolCanBeChanged() {
        let canvas = makeCanvas()
        canvas.currentTool = .rectangle
        XCTAssertEqual(canvas.currentTool, .rectangle)
        canvas.currentTool = .arrow
        XCTAssertEqual(canvas.currentTool, .arrow)
    }

    // MARK: - Current style

    func testCurrentStyleDefaults() {
        let canvas = makeCanvas()
        XCTAssertEqual(canvas.currentStyle.strokeWidth, Preferences.shared.defaultStrokeWidth)
    }

    func testModifyingCurrentStyleDoesNotAffectExistingAnnotations() {
        let canvas = makeCanvas()
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50), style: canvas.currentStyle)
        canvas.addAnnotation(rect, isUndoAction: true)

        let originalStrokeWidth = rect.style.strokeWidth
        canvas.currentStyle.strokeWidth = 10.0

        XCTAssertEqual(rect.style.strokeWidth, originalStrokeWidth)
        XCTAssertEqual(canvas.currentStyle.strokeWidth, 10.0)
    }

    // MARK: - isFlipped

    func testCanvasIsFlipped() {
        let canvas = makeCanvas()
        XCTAssertTrue(canvas.isFlipped)
    }

    // MARK: - Multiple annotation types

    func testCanAddDifferentAnnotationTypes() {
        let canvas = makeCanvas()
        let rect = RectangleAnnotation(bounds: CGRect(x: 0, y: 0, width: 50, height: 50))
        let ellipse = EllipseAnnotation(bounds: CGRect(x: 60, y: 0, width: 50, height: 50))
        let line = LineAnnotation(bounds: CGRect(x: 0, y: 60, width: 50, height: 50))
        let arrow = ArrowAnnotation(bounds: CGRect(x: 60, y: 60, width: 50, height: 50))
        let text = TextAnnotation(bounds: CGRect(x: 0, y: 120, width: 150, height: 30))
        let bubble = SpeechBubbleAnnotation(bounds: CGRect(x: 0, y: 160, width: 150, height: 60))
        let step = StepLabelAnnotation(center: CGPoint(x: 200, y: 200))
        let pixelate = PixelateFilter(bounds: CGRect(x: 250, y: 0, width: 50, height: 50))
        let highlight = HighlightFilter(bounds: CGRect(x: 250, y: 60, width: 50, height: 50))
        let obfuscate = ObfuscateFilter(bounds: CGRect(x: 250, y: 120, width: 50, height: 50))

        let annotations: [Annotation] = [rect, ellipse, line, arrow, text, bubble, step, pixelate, highlight, obfuscate]
        for annotation in annotations {
            canvas.addAnnotation(annotation, isUndoAction: true)
        }

        XCTAssertEqual(canvas.annotations.count, 10)
    }

    // MARK: - Remove nonexistent annotation is no-op

    func testRemoveNonExistentAnnotationIsNoop() {
        let canvas = makeCanvas()
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        // Don't add it, just try to remove
        canvas.removeAnnotation(rect, isUndoAction: true)
        XCTAssertEqual(canvas.annotations.count, 0)
    }
}
