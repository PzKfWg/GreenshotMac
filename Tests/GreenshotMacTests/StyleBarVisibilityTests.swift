import XCTest
import AppKit
@testable import GreenshotMac

@MainActor
final class StyleBarVisibilityTests: XCTestCase {

    private func assertControlVisibility(
        for tool: AnnotationTool,
        controller: EditorWindowController,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let style = controller.canvasView.currentStyle
        controller.updateStyleControls(for: tool, style: style)

        // strokeColorWell visibility matches tool capability
        if let group = controller.strokeControlGroup {
            XCTAssertEqual(!group.isHidden, tool.supportsStrokeColor,
                "\(tool): strokeColorWell visibility mismatch", file: file, line: line)
        }
        if let group = controller.fillControlGroup {
            XCTAssertEqual(!group.isHidden, tool.supportsFillColor,
                "\(tool): fillColorWell visibility mismatch", file: file, line: line)
        }
        if let parent = controller.widthPopup.superview {
            XCTAssertEqual(!parent.isHidden, tool.supportsStrokeWidth,
                "\(tool): widthPopup visibility mismatch", file: file, line: line)
        }
        if let parent = controller.dashPatternPopup.superview {
            XCTAssertEqual(!parent.isHidden, tool.supportsDashPattern,
                "\(tool): dashPatternPopup visibility mismatch", file: file, line: line)
        }
        if let parent = controller.cornerRadiusPopup.superview {
            XCTAssertEqual(!parent.isHidden, tool.supportsCornerRadius,
                "\(tool): cornerRadiusPopup visibility mismatch", file: file, line: line)
        }
        if let parent = controller.opacitySlider.superview {
            XCTAssertEqual(!parent.isHidden, tool.supportsOpacity,
                "\(tool): opacitySlider visibility mismatch", file: file, line: line)
        }
        if let parent = controller.fontSizePopup.superview {
            XCTAssertEqual(!parent.isHidden, tool.supportsFontSize,
                "\(tool): fontSizePopup visibility mismatch", file: file, line: line)
        }
        if let parent = controller.arrowHeadPopup.superview {
            XCTAssertEqual(!parent.isHidden, tool.supportsArrowHeads,
                "\(tool): arrowHeadPopup visibility mismatch", file: file, line: line)
        }
        if let parent = controller.pixelSizePopup.superview {
            XCTAssertEqual(!parent.isHidden, tool.supportsPixelSize,
                "\(tool): pixelSizePopup visibility mismatch", file: file, line: line)
        }
        if let parent = controller.blurRadiusPopup.superview {
            XCTAssertEqual(!parent.isHidden, tool.supportsBlurRadius,
                "\(tool): blurRadiusPopup visibility mismatch", file: file, line: line)
        }
    }

    func testRectangleToolVisibility() {
        let controller = makeEditorController()
        assertControlVisibility(for: .rectangle, controller: controller)
    }

    func testEllipseToolVisibility() {
        let controller = makeEditorController()
        assertControlVisibility(for: .ellipse, controller: controller)
    }

    func testLineToolVisibility() {
        let controller = makeEditorController()
        assertControlVisibility(for: .line, controller: controller)
    }

    func testArrowToolVisibility() {
        let controller = makeEditorController()
        assertControlVisibility(for: .arrow, controller: controller)
    }

    func testTextToolVisibility() {
        let controller = makeEditorController()
        assertControlVisibility(for: .text, controller: controller)
    }

    func testSpeechBubbleToolVisibility() {
        let controller = makeEditorController()
        assertControlVisibility(for: .speechBubble, controller: controller)
    }

    func testStepLabelToolVisibility() {
        let controller = makeEditorController()
        assertControlVisibility(for: .stepLabel, controller: controller)
    }

    func testFreehandToolVisibility() {
        let controller = makeEditorController()
        assertControlVisibility(for: .freehand, controller: controller)
    }

    func testPixelateToolVisibility() {
        let controller = makeEditorController()
        assertControlVisibility(for: .pixelate, controller: controller)
    }

    func testHighlightToolVisibility() {
        let controller = makeEditorController()
        assertControlVisibility(for: .highlight, controller: controller)
    }

    func testObfuscateToolVisibility() {
        let controller = makeEditorController()
        assertControlVisibility(for: .obfuscate, controller: controller)
    }

    func testSelectToolVisibility() {
        let controller = makeEditorController()
        assertControlVisibility(for: .select, controller: controller)
    }

    func testCropToolVisibility() {
        let controller = makeEditorController()
        assertControlVisibility(for: .crop, controller: controller)
    }

    // MARK: - Controls Reflect Selected Annotation Style

    func testControlsReflectSelectedAnnotationStyle() {
        let controller = makeEditorController()
        var style = AnnotationStyle()
        style.strokeColor = .blue
        style.fillColor = .green
        style.strokeWidth = 5.0
        style.opacity = 0.6

        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50), style: style)
        controller.canvasView.addAnnotation(rect, isUndoAction: true)
        controller.canvasView.selectAnnotation(rect)

        // updateStyleControls should have been called via delegate
        XCTAssertEqual(controller.strokeColorWell.color, .blue)
        XCTAssertEqual(controller.fillColorWell.color, .green)
        XCTAssertEqual(controller.opacitySlider.doubleValue, 0.6, accuracy: 0.01)
    }

    // MARK: - isUpdatingControls Set During updateStyleControls

    func testIsUpdatingControlsSetDuringUpdate() {
        let controller = makeEditorController()
        // After updateStyleControls completes, isUpdatingControls should be false
        controller.updateStyleControls(for: .rectangle, style: controller.canvasView.currentStyle)
        XCTAssertFalse(controller.isUpdatingControls,
            "isUpdatingControls should be reset after updateStyleControls completes")
    }
}
