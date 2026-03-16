import XCTest
import AppKit
@testable import GreenshotMac

@MainActor
final class StyleActionTests: XCTestCase {

    // MARK: - Stroke Color

    func testStrokeColorChangedUpdatesCurrentStyle() {
        let controller = makeEditorController()
        controller.strokeColorWell.color = .blue
        controller.strokeColorChanged(controller.strokeColorWell)
        XCTAssertEqual(controller.canvasView.currentStyle.strokeColor, .blue)
    }

    func testStrokeColorChangedAppliesToSelectedAnnotation() {
        let controller = makeEditorController()
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        controller.canvasView.addAnnotation(rect, isUndoAction: true)
        controller.canvasView.selectAnnotation(rect)

        controller.strokeColorWell.color = .green
        controller.strokeColorChanged(controller.strokeColorWell)

        XCTAssertEqual(rect.style.strokeColor, .green)
    }

    func testStrokeColorChangedSavesToPreferences() {
        let controller = makeEditorController()
        let prefs = Preferences.shared
        let original = prefs.defaultStrokeColor

        controller.strokeColorWell.color = .purple
        controller.strokeColorChanged(controller.strokeColorWell)

        XCTAssertEqual(prefs.defaultStrokeColor, .purple)
        prefs.defaultStrokeColor = original
    }

    // MARK: - Fill Color

    func testFillColorChangedUpdatesCurrentStyle() {
        let controller = makeEditorController()
        controller.fillColorWell.color = .yellow
        controller.fillColorChanged(controller.fillColorWell)
        XCTAssertEqual(controller.canvasView.currentStyle.fillColor, .yellow)
    }

    func testFillColorChangedAppliesToSelectedAnnotation() {
        let controller = makeEditorController()
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        controller.canvasView.addAnnotation(rect, isUndoAction: true)
        controller.canvasView.selectAnnotation(rect)

        controller.fillColorWell.color = .cyan
        controller.fillColorChanged(controller.fillColorWell)

        XCTAssertEqual(rect.style.fillColor, .cyan)
    }

    func testFillColorClearAppliesToSelectedAnnotation() {
        let controller = makeEditorController()
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        controller.canvasView.addAnnotation(rect, isUndoAction: true)
        controller.canvasView.selectAnnotation(rect)

        controller.fillColorWell.color = .clear
        controller.fillColorChanged(controller.fillColorWell)

        XCTAssertEqual(rect.style.fillColor.alphaComponent, 0.0, accuracy: 0.01,
            ".clear fill should propagate to selected annotation")
    }

    // MARK: - Stroke Width

    func testWidthChangedUpdatesCurrentStyle() {
        let controller = makeEditorController()
        // Select an item with a known tag
        if let item = controller.widthPopup.itemArray.first(where: { $0.tag == 4 }) {
            controller.widthPopup.select(item)
            controller.widthChanged(controller.widthPopup)
            XCTAssertEqual(controller.canvasView.currentStyle.strokeWidth, 4.0)
        }
    }

    // MARK: - Bold / Italic

    func testBoldChangedTogglesFontBold() {
        let controller = makeEditorController()
        controller.boldButton.state = .on
        controller.boldChanged(controller.boldButton)
        XCTAssertTrue(controller.canvasView.currentStyle.fontBold)

        controller.boldButton.state = .off
        controller.boldChanged(controller.boldButton)
        XCTAssertFalse(controller.canvasView.currentStyle.fontBold)
    }

    func testItalicChangedTogglesFontItalic() {
        let controller = makeEditorController()
        controller.italicButton.state = .on
        controller.italicChanged(controller.italicButton)
        XCTAssertTrue(controller.canvasView.currentStyle.fontItalic)

        controller.italicButton.state = .off
        controller.italicChanged(controller.italicButton)
        XCTAssertFalse(controller.canvasView.currentStyle.fontItalic)
    }

    // MARK: - Underline

    func testUnderlineChangedToggles() {
        let controller = makeEditorController()
        controller.underlineButton.state = .on
        controller.underlineChanged(controller.underlineButton)
        XCTAssertTrue(controller.canvasView.currentStyle.fontUnderline)

        controller.underlineButton.state = .off
        controller.underlineChanged(controller.underlineButton)
        XCTAssertFalse(controller.canvasView.currentStyle.fontUnderline)
    }

    // MARK: - Opacity

    func testOpacityChangedUpdatesCurrentStyle() {
        let controller = makeEditorController()
        controller.opacitySlider.doubleValue = 0.5
        controller.opacityChanged(controller.opacitySlider)
        XCTAssertEqual(controller.canvasView.currentStyle.opacity, 0.5, accuracy: 0.01)
    }

    func testOpacityChangedAppliesToSelectedAnnotation() {
        let controller = makeEditorController()
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        controller.canvasView.addAnnotation(rect, isUndoAction: true)
        controller.canvasView.selectAnnotation(rect)

        controller.opacitySlider.doubleValue = 0.3
        controller.opacityChanged(controller.opacitySlider)

        XCTAssertEqual(rect.style.opacity, 0.3, accuracy: 0.01)
    }

    // MARK: - Dash Pattern

    func testDashPatternChangedUpdatesDashed() {
        let controller = makeEditorController()
        if let item = controller.dashPatternPopup.itemArray.first(where: { $0.tag == 1 }) {
            controller.dashPatternPopup.select(item)
            controller.dashPatternChanged(controller.dashPatternPopup)
            XCTAssertEqual(controller.canvasView.currentStyle.dashPattern, .dashed)
        }
    }

    func testDashPatternChangedUpdatesDotted() {
        let controller = makeEditorController()
        if let item = controller.dashPatternPopup.itemArray.first(where: { $0.tag == 2 }) {
            controller.dashPatternPopup.select(item)
            controller.dashPatternChanged(controller.dashPatternPopup)
            XCTAssertEqual(controller.canvasView.currentStyle.dashPattern, .dotted)
        }
    }

    func testDashPatternChangedUpdatesSolid() {
        let controller = makeEditorController()
        if let item = controller.dashPatternPopup.itemArray.first(where: { $0.tag == 0 }) {
            controller.dashPatternPopup.select(item)
            controller.dashPatternChanged(controller.dashPatternPopup)
            XCTAssertEqual(controller.canvasView.currentStyle.dashPattern, .solid)
        }
    }

    // MARK: - Corner Radius

    func testCornerRadiusChangedAppliesToRectangle() {
        let controller = makeEditorController()
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 80, height: 60))
        controller.canvasView.addAnnotation(rect, isUndoAction: true)
        controller.canvasView.selectAnnotation(rect)

        if let item = controller.cornerRadiusPopup.itemArray.first(where: { $0.tag == 8 }) {
            controller.cornerRadiusPopup.select(item)
            controller.cornerRadiusChanged(controller.cornerRadiusPopup)
            XCTAssertEqual(rect.cornerRadius, 8.0)
        }
    }

    // MARK: - Arrow Heads

    func testArrowHeadChangedAppliesToArrow() {
        let controller = makeEditorController()
        let arrow = ArrowAnnotation(bounds: CGRect(x: 10, y: 10, width: 80, height: 60))
        controller.canvasView.addAnnotation(arrow, isUndoAction: true)
        controller.canvasView.selectAnnotation(arrow)

        // Tag 2 = .both
        if let item = controller.arrowHeadPopup.itemArray.first(where: { $0.tag == 2 }) {
            controller.arrowHeadPopup.select(item)
            controller.arrowHeadChanged(controller.arrowHeadPopup)
            XCTAssertEqual(arrow.arrowHeads, .both)
        }
    }

    // MARK: - isUpdatingControls Guard

    func testActionsBlockedWhenIsUpdatingControls() {
        let controller = makeEditorController()
        let originalColor = controller.canvasView.currentStyle.strokeColor

        controller.isUpdatingControls = true
        controller.strokeColorWell.color = .orange
        controller.strokeColorChanged(controller.strokeColorWell)

        XCTAssertEqual(controller.canvasView.currentStyle.strokeColor, originalColor,
            "Actions should be blocked when isUpdatingControls is true")
        controller.isUpdatingControls = false
    }

    // MARK: - Font Name

    func testFontNameChangedUpdatesCurrentStyle() {
        let controller = makeEditorController()
        if let item = controller.fontNamePopup.itemArray.first(where: { $0.title == "Courier" }) {
            controller.fontNamePopup.select(item)
            controller.fontNameChanged(controller.fontNamePopup)
            XCTAssertEqual(controller.canvasView.currentStyle.fontName, "Courier")
        }
    }

    // MARK: - Text Alignment

    func testTextAlignChangedUpdatesHorizontalAlignment() {
        let controller = makeEditorController()
        // Tag 0 = left
        if let item = controller.textAlignPopup.itemArray.first(where: { $0.tag == 0 }) {
            controller.textAlignPopup.select(item)
            controller.textAlignChanged(controller.textAlignPopup)
            XCTAssertEqual(controller.canvasView.currentStyle.textHorizontalAlignment, .left)
        }
    }

    func testTextVerticalAlignChangedUpdatesVerticalAlignment() {
        let controller = makeEditorController()
        // Tag 0 = top
        if let item = controller.textVerticalAlignPopup.itemArray.first(where: { $0.tag == 0 }) {
            controller.textVerticalAlignPopup.select(item)
            controller.textVerticalAlignChanged(controller.textVerticalAlignPopup)
            XCTAssertEqual(controller.canvasView.currentStyle.textVerticalAlignment, .top)
        }
    }

    // MARK: - Pixel Size

    func testPixelSizeChangedAppliesToPixelateFilter() {
        let controller = makeEditorController()
        let pf = PixelateFilter(bounds: CGRect(x: 10, y: 10, width: 80, height: 60))
        controller.canvasView.addAnnotation(pf, isUndoAction: true)
        controller.canvasView.selectAnnotation(pf)

        if let item = controller.pixelSizePopup.itemArray.first(where: { $0.tag == 10 }) {
            controller.pixelSizePopup.select(item)
            controller.pixelSizeChanged(controller.pixelSizePopup)
            XCTAssertEqual(pf.pixelSize, 10)
        }
    }

    // MARK: - Blur Radius

    func testBlurRadiusChangedAppliesToObfuscateFilter() {
        let controller = makeEditorController()
        let of = ObfuscateFilter(bounds: CGRect(x: 10, y: 10, width: 80, height: 60))
        controller.canvasView.addAnnotation(of, isUndoAction: true)
        controller.canvasView.selectAnnotation(of)

        if let item = controller.blurRadiusPopup.itemArray.first(where: { $0.tag == 20 }) {
            controller.blurRadiusPopup.select(item)
            controller.blurRadiusChanged(controller.blurRadiusPopup)
            XCTAssertEqual(of.blurRadius, 20)
        }
    }
}
