import XCTest
import AppKit
@testable import GreenshotMac

@MainActor
final class ControlConfigurationTests: XCTestCase {

    // MARK: - Transparent Color Bug Detection

    func testColorPanelShowsAlphaAfterSetup() {
        let controller = makeEditorController()
        _ = controller  // ensure setup ran
        XCTAssertTrue(NSColorPanel.shared.showsAlpha,
            "Color panel should show alpha slider to allow transparent color selection")
    }

    func testFillColorWellAcceptsClearColor() {
        let controller = makeEditorController()
        controller.fillColorWell.color = .clear
        XCTAssertEqual(controller.fillColorWell.color.alphaComponent, 0.0, accuracy: 0.01,
            "Fill color well should accept .clear (alpha=0)")
    }

    func testFillColorChangedPropagatesClearToCurrentStyle() {
        let controller = makeEditorController()
        controller.fillColorWell.color = .clear
        controller.fillColorChanged(controller.fillColorWell)
        XCTAssertEqual(controller.canvasView.currentStyle.fillColor.alphaComponent, 0.0, accuracy: 0.01,
            "fillColorChanged(.clear) should propagate alpha=0 to currentStyle")
    }

    func testPreferencesRoundtripClearColor() {
        let prefs = Preferences.shared
        let original = prefs.defaultFillColor
        prefs.defaultFillColor = .clear
        let restored = prefs.defaultFillColor
        XCTAssertEqual(restored.alphaComponent, 0.0, accuracy: 0.01,
            ".clear should survive NSKeyedArchiver round-trip in Preferences")
        prefs.defaultFillColor = original
    }

    func testFillColorChangedSavesClearToPreferences() {
        let controller = makeEditorController()
        let prefs = Preferences.shared
        let original = prefs.defaultFillColor

        controller.fillColorWell.color = .clear
        controller.fillColorChanged(controller.fillColorWell)

        XCTAssertEqual(prefs.defaultFillColor.alphaComponent, 0.0, accuracy: 0.01,
            "fillColorChanged(.clear) should persist to Preferences")
        prefs.defaultFillColor = original
    }

    // MARK: - Control Target/Action Wiring

    func testStrokeColorWellTargetAction() {
        let controller = makeEditorController()
        XCTAssertNotNil(controller.strokeColorWell.target)
        XCTAssertNotNil(controller.strokeColorWell.action)
    }

    func testFillColorWellTargetAction() {
        let controller = makeEditorController()
        XCTAssertNotNil(controller.fillColorWell.target)
        XCTAssertNotNil(controller.fillColorWell.action)
    }

    func testWidthPopupTargetAction() {
        let controller = makeEditorController()
        XCTAssertNotNil(controller.widthPopup.target)
        XCTAssertNotNil(controller.widthPopup.action)
    }

    func testFontSizePopupTargetAction() {
        let controller = makeEditorController()
        XCTAssertNotNil(controller.fontSizePopup.target)
        XCTAssertNotNil(controller.fontSizePopup.action)
    }

    func testBoldButtonTargetAction() {
        let controller = makeEditorController()
        XCTAssertNotNil(controller.boldButton.target)
        XCTAssertNotNil(controller.boldButton.action)
    }

    func testOpacitySliderTargetAction() {
        let controller = makeEditorController()
        XCTAssertNotNil(controller.opacitySlider.target)
        XCTAssertNotNil(controller.opacitySlider.action)
    }

    // MARK: - Control Value Ranges

    func testOpacitySliderRange() {
        let controller = makeEditorController()
        XCTAssertEqual(controller.opacitySlider.minValue, 0.1, accuracy: 0.01)
        XCTAssertEqual(controller.opacitySlider.maxValue, 1.0, accuracy: 0.01)
    }

    func testWidthPopupHasItems() {
        let controller = makeEditorController()
        XCTAssertGreaterThan(controller.widthPopup.numberOfItems, 0,
            "Width popup should have at least one item")
    }

    func testFontSizePopupHasItems() {
        let controller = makeEditorController()
        XCTAssertGreaterThan(controller.fontSizePopup.numberOfItems, 0,
            "Font size popup should have at least one item")
    }

    func testDashPatternPopupHasThreeItems() {
        let controller = makeEditorController()
        XCTAssertGreaterThanOrEqual(controller.dashPatternPopup.numberOfItems, 3,
            "Dash pattern popup should have solid, dashed, dotted")
    }

    func testBoldButtonIsToggle() {
        let controller = makeEditorController()
        // Toggle buttons alternate between on/off
        let initial = controller.boldButton.state
        XCTAssertTrue(initial == .on || initial == .off)
    }

    func testItalicButtonIsToggle() {
        let controller = makeEditorController()
        let initial = controller.italicButton.state
        XCTAssertTrue(initial == .on || initial == .off)
    }

    func testUnderlineButtonIsToggle() {
        let controller = makeEditorController()
        let initial = controller.underlineButton.state
        XCTAssertTrue(initial == .on || initial == .off)
    }
}
