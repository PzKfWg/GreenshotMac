import XCTest
import AppKit
@testable import GreenshotMac

@MainActor
final class UndoManagerTests: XCTestCase {

    // MARK: - Helpers

    private func makeCanvas() -> CanvasView {
        let canvas = CanvasView()
        canvas.setupUndoManager()
        let image = NSImage(size: NSSize(width: 400, height: 300))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: image.size).fill()
        image.unlockFocus()
        canvas.backgroundImage = image
        canvas.frame = CGRect(origin: .zero, size: CGSize(width: 400, height: 300))
        return canvas
    }

    // MARK: - Undo Add

    func testUndoAddRemovesAnnotation() {
        let canvas = makeCanvas()
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        canvas.addAnnotation(rect)

        XCTAssertEqual(canvas.annotations.count, 1)

        canvas.annotationUndoManager.nsUndoManager.undo()

        XCTAssertEqual(canvas.annotations.count, 0)
    }

    func testRedoAddReAddsAnnotation() {
        let canvas = makeCanvas()
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        canvas.addAnnotation(rect)

        canvas.annotationUndoManager.nsUndoManager.undo()
        XCTAssertEqual(canvas.annotations.count, 0)

        canvas.annotationUndoManager.nsUndoManager.redo()
        XCTAssertEqual(canvas.annotations.count, 1)
        XCTAssertEqual(canvas.annotations.first?.id, rect.id)
    }

    // MARK: - Undo Remove

    func testUndoRemoveReInsertsAnnotation() {
        let canvas = makeCanvas()
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        canvas.addAnnotation(rect, isUndoAction: true) // Don't record add as undo

        canvas.removeAnnotation(rect) // Records remove in undo

        XCTAssertEqual(canvas.annotations.count, 0)

        canvas.annotationUndoManager.nsUndoManager.undo()

        XCTAssertEqual(canvas.annotations.count, 1)
        XCTAssertEqual(canvas.annotations.first?.id, rect.id)
    }

    func testRedoRemoveRemovesAgain() {
        let canvas = makeCanvas()
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        canvas.addAnnotation(rect, isUndoAction: true)

        canvas.removeAnnotation(rect)
        canvas.annotationUndoManager.nsUndoManager.undo()
        XCTAssertEqual(canvas.annotations.count, 1)

        canvas.annotationUndoManager.nsUndoManager.redo()
        XCTAssertEqual(canvas.annotations.count, 0)
    }

    // MARK: - Undo Modify

    func testUndoModifyRestoresOldBounds() {
        let canvas = makeCanvas()
        let originalBounds = CGRect(x: 10, y: 10, width: 50, height: 50)
        let rect = RectangleAnnotation(bounds: originalBounds)
        canvas.addAnnotation(rect, isUndoAction: true)

        let oldBounds = rect.bounds
        let oldStyle = rect.style
        rect.bounds = CGRect(x: 100, y: 100, width: 200, height: 200)
        canvas.annotationUndoManager.recordModify(rect, oldBounds: oldBounds, oldStyle: oldStyle)

        XCTAssertEqual(rect.bounds, CGRect(x: 100, y: 100, width: 200, height: 200))

        canvas.annotationUndoManager.nsUndoManager.undo()

        XCTAssertEqual(rect.bounds, originalBounds)
    }

    func testRedoModifyRestoresNewBounds() {
        let canvas = makeCanvas()
        let originalBounds = CGRect(x: 10, y: 10, width: 50, height: 50)
        let newBounds = CGRect(x: 100, y: 100, width: 200, height: 200)
        let rect = RectangleAnnotation(bounds: originalBounds)
        canvas.addAnnotation(rect, isUndoAction: true)

        let oldBounds = rect.bounds
        let oldStyle = rect.style
        rect.bounds = newBounds
        canvas.annotationUndoManager.recordModify(rect, oldBounds: oldBounds, oldStyle: oldStyle)

        canvas.annotationUndoManager.nsUndoManager.undo()
        XCTAssertEqual(rect.bounds, originalBounds)

        canvas.annotationUndoManager.nsUndoManager.redo()
        XCTAssertEqual(rect.bounds, newBounds)
    }

    // MARK: - Multiple undo/redo

    func testMultipleUndoInSequence() {
        let canvas = makeCanvas()
        let um = canvas.annotationUndoManager.nsUndoManager
        um.groupsByEvent = false

        let rect1 = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        let rect2 = RectangleAnnotation(bounds: CGRect(x: 100, y: 100, width: 50, height: 50))

        um.beginUndoGrouping()
        canvas.addAnnotation(rect1)
        um.endUndoGrouping()

        um.beginUndoGrouping()
        canvas.addAnnotation(rect2)
        um.endUndoGrouping()

        XCTAssertEqual(canvas.annotations.count, 2)

        // Undo adding rect2
        um.undo()
        XCTAssertEqual(canvas.annotations.count, 1)
        XCTAssertEqual(canvas.annotations.first?.id, rect1.id)

        // Undo adding rect1
        um.undo()
        XCTAssertEqual(canvas.annotations.count, 0)
    }

    func testUndoThenRedoSingleAnnotation() {
        let canvas = makeCanvas()
        let um = canvas.annotationUndoManager.nsUndoManager
        um.groupsByEvent = false

        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))

        um.beginUndoGrouping()
        canvas.addAnnotation(rect)
        um.endUndoGrouping()

        XCTAssertEqual(canvas.annotations.count, 1)

        um.undo()
        XCTAssertEqual(canvas.annotations.count, 0)

        um.redo()
        XCTAssertEqual(canvas.annotations.count, 1)
        XCTAssertEqual(canvas.annotations.first?.id, rect.id)
    }

    // MARK: - Undo manager exposed via undoManager property

    func testUndoManagerExposedViaProperty() {
        let canvas = makeCanvas()
        XCTAssertNotNil(canvas.undoManager)
        XCTAssertTrue(canvas.undoManager === canvas.annotationUndoManager.nsUndoManager)
    }
}
