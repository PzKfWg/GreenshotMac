import XCTest
import AppKit
@testable import GreenshotMac

@MainActor
final class HighlightColorTests: XCTestCase {

    // MARK: - Task 1: Preferences.defaultHighlightColor

    func testDefaultHighlightColorDefaultsToTranslucentYellow() {
        let prefs = Preferences.shared
        let original = prefs.defaultHighlightColor
        // Reset to absent state to exercise the default branch.
        UserDefaults.standard.removeObject(forKey: "defaultHighlightColorData")

        let expected = NSColor.yellow.withAlphaComponent(0.4)
        let actual = prefs.defaultHighlightColor
        XCTAssertEqual(actual.alphaComponent, expected.alphaComponent, accuracy: 0.01)
        let rgbActual = actual.usingColorSpace(.sRGB)
        let rgbExpected = expected.usingColorSpace(.sRGB)
        XCTAssertEqual(rgbActual?.redComponent ?? -1, rgbExpected?.redComponent ?? -2, accuracy: 0.01)
        XCTAssertEqual(rgbActual?.greenComponent ?? -1, rgbExpected?.greenComponent ?? -2, accuracy: 0.01)
        XCTAssertEqual(rgbActual?.blueComponent ?? -1, rgbExpected?.blueComponent ?? -2, accuracy: 0.01)

        prefs.defaultHighlightColor = original
    }

    func testDefaultHighlightColorPersists() {
        let prefs = Preferences.shared
        let original = prefs.defaultHighlightColor

        prefs.defaultHighlightColor = .magenta
        XCTAssertEqual(prefs.defaultHighlightColor, .magenta)

        prefs.defaultHighlightColor = original
    }

    // MARK: - Task 2: Persistence routed by active tool

    func testFillColorChangedPersistsToHighlightWhenHighlightActive() {
        let controller = makeEditorController()
        let prefs = Preferences.shared
        let originalFill = prefs.defaultFillColor
        let originalHighlight = prefs.defaultHighlightColor

        controller.canvasView.currentTool = .highlight
        controller.fillColorWell.color = .magenta
        controller.fillColorChanged(controller.fillColorWell)

        XCTAssertEqual(prefs.defaultHighlightColor, .magenta,
            "Highlight tool active -> change must persist to defaultHighlightColor")
        XCTAssertEqual(prefs.defaultFillColor, originalFill,
            "Shared fill color must not change while highlight is active")

        prefs.defaultFillColor = originalFill
        prefs.defaultHighlightColor = originalHighlight
    }

    func testFillColorChangedPersistsToFillWhenRectangleActive() {
        let controller = makeEditorController()
        let prefs = Preferences.shared
        let originalFill = prefs.defaultFillColor
        let originalHighlight = prefs.defaultHighlightColor

        controller.canvasView.currentTool = .rectangle
        controller.fillColorWell.color = .cyan
        controller.fillColorChanged(controller.fillColorWell)

        XCTAssertEqual(prefs.defaultFillColor, .cyan,
            "Non-highlight tool -> change must persist to defaultFillColor")
        XCTAssertEqual(prefs.defaultHighlightColor, originalHighlight,
            "Highlight color must not change for non-highlight tools")

        prefs.defaultFillColor = originalFill
        prefs.defaultHighlightColor = originalHighlight
    }

    // MARK: - Task 3: Tool-switch seeding of currentStyle.fillColor

    func testSwitchingToHighlightSeedsHighlightColor() {
        let controller = makeEditorController()
        let prefs = Preferences.shared
        let originalFill = prefs.defaultFillColor
        let originalHighlight = prefs.defaultHighlightColor

        prefs.defaultFillColor = .white
        prefs.defaultHighlightColor = .yellow

        controller.canvasView.currentTool = .rectangle
        XCTAssertEqual(controller.canvasView.currentStyle.fillColor, .white,
            "Rectangle should seed the shared fill color")

        controller.canvasView.currentTool = .highlight
        XCTAssertEqual(controller.canvasView.currentStyle.fillColor, .yellow,
            "Highlight should seed its dedicated color, not the shared white")

        controller.canvasView.currentTool = .rectangle
        XCTAssertEqual(controller.canvasView.currentStyle.fillColor, .white,
            "Returning to rectangle should restore the shared fill color")

        prefs.defaultFillColor = originalFill
        prefs.defaultHighlightColor = originalHighlight
    }

    // MARK: - Task 4: HighlightFilter is never colourless

    func testHighlightFilterFallsBackToManagedColorWhenFillClear() {
        let prefs = Preferences.shared
        let originalHighlight = prefs.defaultHighlightColor
        prefs.defaultHighlightColor = .orange

        var clearStyle = AnnotationStyle()
        clearStyle.fillColor = .clear
        let filter = HighlightFilter(bounds: CGRect(x: 0, y: 0, width: 100, height: 50),
                                     style: clearStyle)

        XCTAssertEqual(filter.style.fillColor, .orange,
            "A clear-fill highlight must adopt the managed highlight color")

        prefs.defaultHighlightColor = originalHighlight
    }

    func testHighlightFilterPreservesExplicitFillColor() {
        var greenStyle = AnnotationStyle()
        greenStyle.fillColor = .green
        let filter = HighlightFilter(bounds: CGRect(x: 0, y: 0, width: 100, height: 50),
                                     style: greenStyle)

        XCTAssertEqual(filter.style.fillColor, .green,
            "An explicit fill color must be preserved")
    }
}
