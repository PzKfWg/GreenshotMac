import XCTest
import AppKit
@testable import GreenshotMac

@MainActor
final class UndoStyleTests: XCTestCase {

    // MARK: - Undo Fill Color Change

    func testUndoFillColorChange() {
        let controller = makeEditorController()
        var style = AnnotationStyle()
        style.fillColor = .red
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50), style: style)
        controller.canvasView.addAnnotation(rect, isUndoAction: true)
        controller.canvasView.selectAnnotation(rect)

        // Change fill to blue via action
        controller.fillColorWell.color = .blue
        controller.fillColorChanged(controller.fillColorWell)
        XCTAssertEqual(rect.style.fillColor, .blue)

        // Undo
        controller.performUndo(nil)
        XCTAssertEqual(rect.style.fillColor, .red,
            "Undo should restore original fill color")
    }

    // MARK: - Undo Stroke Color Change

    func testUndoStrokeColorChange() {
        let controller = makeEditorController()
        var style = AnnotationStyle()
        style.strokeColor = .black
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50), style: style)
        controller.canvasView.addAnnotation(rect, isUndoAction: true)
        controller.canvasView.selectAnnotation(rect)

        controller.strokeColorWell.color = .orange
        controller.strokeColorChanged(controller.strokeColorWell)
        XCTAssertEqual(rect.style.strokeColor, .orange)

        controller.performUndo(nil)
        XCTAssertEqual(rect.style.strokeColor, .black,
            "Undo should restore original stroke color")
    }

    // MARK: - Undo Opacity Change

    func testUndoOpacityChange() {
        let controller = makeEditorController()
        var style = AnnotationStyle()
        style.opacity = 1.0
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50), style: style)
        controller.canvasView.addAnnotation(rect, isUndoAction: true)
        controller.canvasView.selectAnnotation(rect)

        controller.opacitySlider.doubleValue = 0.4
        controller.opacityChanged(controller.opacitySlider)
        XCTAssertEqual(rect.style.opacity, 0.4, accuracy: 0.01)

        controller.performUndo(nil)
        XCTAssertEqual(rect.style.opacity, 1.0, accuracy: 0.01,
            "Undo should restore original opacity")
    }

    // MARK: - Undo Dash Pattern Change

    func testUndoDashPatternChange() {
        let controller = makeEditorController()
        var style = AnnotationStyle()
        style.dashPattern = .solid
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50), style: style)
        controller.canvasView.addAnnotation(rect, isUndoAction: true)
        controller.canvasView.selectAnnotation(rect)

        if let item = controller.dashPatternPopup.itemArray.first(where: { $0.tag == 1 }) {
            controller.dashPatternPopup.select(item)
            controller.dashPatternChanged(controller.dashPatternPopup)
            XCTAssertEqual(rect.style.dashPattern, .dashed)

            controller.performUndo(nil)
            XCTAssertEqual(rect.style.dashPattern, .solid,
                "Undo should restore original dash pattern")
        }
    }

    // MARK: - Redo After Undo

    func testRedoRestoresChange() {
        let controller = makeEditorController()
        var style = AnnotationStyle()
        style.fillColor = .red
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50), style: style)
        controller.canvasView.addAnnotation(rect, isUndoAction: true)
        controller.canvasView.selectAnnotation(rect)

        controller.fillColorWell.color = .blue
        controller.fillColorChanged(controller.fillColorWell)
        controller.performUndo(nil)
        XCTAssertEqual(rect.style.fillColor, .red)

        controller.performRedo(nil)
        XCTAssertEqual(rect.style.fillColor, .blue,
            "Redo should restore the changed fill color")
    }

    // MARK: - Undo Arrow Head Change

    func testUndoArrowHeadChange() {
        let controller = makeEditorController()
        let arrow = ArrowAnnotation(bounds: CGRect(x: 10, y: 10, width: 80, height: 60))
        controller.canvasView.addAnnotation(arrow, isUndoAction: true)
        controller.canvasView.selectAnnotation(arrow)
        let originalHeads = arrow.arrowHeads

        // Change to .both (tag 2)
        if let item = controller.arrowHeadPopup.itemArray.first(where: { $0.tag == 2 }) {
            controller.arrowHeadPopup.select(item)
            controller.arrowHeadChanged(controller.arrowHeadPopup)
            XCTAssertEqual(arrow.arrowHeads, .both)

            controller.performUndo(nil)
            XCTAssertEqual(arrow.arrowHeads, originalHeads,
                "Undo should restore original arrow heads")
        }
    }

    // MARK: - Undo Corner Radius Change

    func testUndoCornerRadiusChange() {
        let controller = makeEditorController()
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 80, height: 60))
        controller.canvasView.addAnnotation(rect, isUndoAction: true)
        controller.canvasView.selectAnnotation(rect)
        let originalRadius = rect.cornerRadius

        if let item = controller.cornerRadiusPopup.itemArray.first(where: { $0.tag == 12 }) {
            controller.cornerRadiusPopup.select(item)
            controller.cornerRadiusChanged(controller.cornerRadiusPopup)
            XCTAssertEqual(rect.cornerRadius, 12.0)

            controller.performUndo(nil)
            XCTAssertEqual(rect.cornerRadius, originalRadius,
                "Undo should restore original corner radius")
        }
    }
}
