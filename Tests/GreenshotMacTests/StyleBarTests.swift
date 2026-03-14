import XCTest
import AppKit
@testable import GreenshotMac

@MainActor
final class AnnotationToolCapabilityTests: XCTestCase {

    // MARK: - supportsStrokeColor

    func testStrokeColorSupportedTools() {
        let supported: [AnnotationTool] = [.rectangle, .ellipse, .line, .arrow, .freehand, .text, .speechBubble, .stepLabel]
        for tool in supported {
            XCTAssertTrue(tool.supportsStrokeColor, "\(tool) should support stroke color")
        }
    }

    func testStrokeColorUnsupportedTools() {
        let unsupported: [AnnotationTool] = [.select, .pixelate, .highlight, .obfuscate, .crop]
        for tool in unsupported {
            XCTAssertFalse(tool.supportsStrokeColor, "\(tool) should not support stroke color")
        }
    }

    // MARK: - supportsFillColor

    func testFillColorSupportedTools() {
        let supported: [AnnotationTool] = [.rectangle, .ellipse, .text, .speechBubble, .stepLabel, .highlight]
        for tool in supported {
            XCTAssertTrue(tool.supportsFillColor, "\(tool) should support fill color")
        }
    }

    func testFillColorUnsupportedTools() {
        let unsupported: [AnnotationTool] = [.select, .line, .arrow, .freehand, .pixelate, .obfuscate, .crop]
        for tool in unsupported {
            XCTAssertFalse(tool.supportsFillColor, "\(tool) should not support fill color")
        }
    }

    // MARK: - supportsStrokeWidth

    func testStrokeWidthSupportedTools() {
        let supported: [AnnotationTool] = [.rectangle, .ellipse, .line, .arrow, .freehand, .text, .speechBubble]
        for tool in supported {
            XCTAssertTrue(tool.supportsStrokeWidth, "\(tool) should support stroke width")
        }
    }

    func testStrokeWidthUnsupportedTools() {
        let unsupported: [AnnotationTool] = [.select, .stepLabel, .pixelate, .highlight, .obfuscate, .crop]
        for tool in unsupported {
            XCTAssertFalse(tool.supportsStrokeWidth, "\(tool) should not support stroke width")
        }
    }

    // MARK: - supportsPixelSize

    func testPixelSizeSupportedTools() {
        XCTAssertTrue(AnnotationTool.pixelate.supportsPixelSize)
    }

    func testPixelSizeUnsupportedTools() {
        let unsupported: [AnnotationTool] = [.select, .rectangle, .ellipse, .line, .arrow, .freehand, .text, .speechBubble, .stepLabel, .highlight, .obfuscate, .crop]
        for tool in unsupported {
            XCTAssertFalse(tool.supportsPixelSize, "\(tool) should not support pixel size")
        }
    }

    // MARK: - supportsShadow

    func testShadowSupportedTools() {
        let supported: [AnnotationTool] = [.rectangle, .ellipse, .line, .arrow, .freehand, .text, .speechBubble, .stepLabel]
        for tool in supported {
            XCTAssertTrue(tool.supportsShadow, "\(tool) should support shadow")
        }
    }

    func testShadowUnsupportedTools() {
        let unsupported: [AnnotationTool] = [.select, .pixelate, .highlight, .obfuscate, .crop]
        for tool in unsupported {
            XCTAssertFalse(tool.supportsShadow, "\(tool) should not support shadow")
        }
    }

    // MARK: - supportsDashPattern

    func testDashPatternSupportedTools() {
        let supported: [AnnotationTool] = [.rectangle, .ellipse, .line, .arrow, .freehand, .text, .speechBubble]
        for tool in supported {
            XCTAssertTrue(tool.supportsDashPattern, "\(tool) should support dash pattern")
        }
    }

    func testDashPatternUnsupportedTools() {
        let unsupported: [AnnotationTool] = [.select, .stepLabel, .pixelate, .highlight, .obfuscate, .crop]
        for tool in unsupported {
            XCTAssertFalse(tool.supportsDashPattern, "\(tool) should not support dash pattern")
        }
    }

    // MARK: - supportsCornerRadius

    func testCornerRadiusSupportedTools() {
        XCTAssertTrue(AnnotationTool.rectangle.supportsCornerRadius)
    }

    func testCornerRadiusUnsupportedTools() {
        let unsupported: [AnnotationTool] = [.select, .ellipse, .line, .arrow, .freehand, .text, .speechBubble, .stepLabel, .pixelate, .highlight, .obfuscate, .crop]
        for tool in unsupported {
            XCTAssertFalse(tool.supportsCornerRadius, "\(tool) should not support corner radius")
        }
    }

    // MARK: - supportsOpacity

    func testOpacitySupportedTools() {
        let supported: [AnnotationTool] = [.rectangle, .ellipse, .line, .arrow, .freehand, .text, .speechBubble, .stepLabel, .highlight]
        for tool in supported {
            XCTAssertTrue(tool.supportsOpacity, "\(tool) should support opacity")
        }
    }

    func testOpacityUnsupportedTools() {
        let unsupported: [AnnotationTool] = [.select, .pixelate, .obfuscate, .crop]
        for tool in unsupported {
            XCTAssertFalse(tool.supportsOpacity, "\(tool) should not support opacity")
        }
    }

    // MARK: - supportsFontSize

    func testFontSizeSupportedTools() {
        let supported: [AnnotationTool] = [.text, .speechBubble]
        for tool in supported {
            XCTAssertTrue(tool.supportsFontSize, "\(tool) should support font size")
        }
    }

    func testFontSizeUnsupportedTools() {
        let unsupported: [AnnotationTool] = [.select, .rectangle, .ellipse, .line, .arrow, .freehand, .stepLabel, .pixelate, .highlight, .obfuscate, .crop]
        for tool in unsupported {
            XCTAssertFalse(tool.supportsFontSize, "\(tool) should not support font size")
        }
    }

    // MARK: - supportsFontStyle

    func testFontStyleSupportedTools() {
        let supported: [AnnotationTool] = [.text, .speechBubble]
        for tool in supported {
            XCTAssertTrue(tool.supportsFontStyle, "\(tool) should support font style")
        }
    }

    func testFontStyleUnsupportedTools() {
        let unsupported: [AnnotationTool] = [.select, .rectangle, .ellipse, .line, .arrow, .freehand, .stepLabel, .pixelate, .highlight, .obfuscate, .crop]
        for tool in unsupported {
            XCTAssertFalse(tool.supportsFontStyle, "\(tool) should not support font style")
        }
    }

    // MARK: - supportsTextAlignment

    func testTextAlignmentSupportedTools() {
        let supported: [AnnotationTool] = [.text, .speechBubble]
        for tool in supported {
            XCTAssertTrue(tool.supportsTextAlignment, "\(tool) should support text alignment")
        }
    }

    func testTextAlignmentUnsupportedTools() {
        let unsupported: [AnnotationTool] = [.select, .rectangle, .ellipse, .line, .arrow, .freehand, .stepLabel, .pixelate, .highlight, .obfuscate, .crop]
        for tool in unsupported {
            XCTAssertFalse(tool.supportsTextAlignment, "\(tool) should not support text alignment")
        }
    }

    // MARK: - supportsUnderline

    func testUnderlineSupportedTools() {
        let supported: [AnnotationTool] = [.text, .speechBubble]
        for tool in supported {
            XCTAssertTrue(tool.supportsUnderline, "\(tool) should support underline")
        }
    }

    func testUnderlineUnsupportedTools() {
        let unsupported: [AnnotationTool] = [.select, .rectangle, .ellipse, .line, .arrow, .freehand, .stepLabel, .pixelate, .highlight, .obfuscate, .crop]
        for tool in unsupported {
            XCTAssertFalse(tool.supportsUnderline, "\(tool) should not support underline")
        }
    }

    // MARK: - supportsArrowHeads

    func testArrowHeadsSupportedTools() {
        XCTAssertTrue(AnnotationTool.arrow.supportsArrowHeads)
    }

    func testArrowHeadsUnsupportedTools() {
        let unsupported: [AnnotationTool] = [.select, .rectangle, .ellipse, .line, .freehand, .text, .speechBubble, .stepLabel, .pixelate, .highlight, .obfuscate, .crop]
        for tool in unsupported {
            XCTAssertFalse(tool.supportsArrowHeads, "\(tool) should not support arrow heads")
        }
    }

    // MARK: - supportsBlurRadius

    func testBlurRadiusSupportedTools() {
        XCTAssertTrue(AnnotationTool.obfuscate.supportsBlurRadius)
    }

    func testBlurRadiusUnsupportedTools() {
        let unsupported: [AnnotationTool] = [.select, .rectangle, .ellipse, .line, .arrow, .freehand, .text, .speechBubble, .stepLabel, .pixelate, .highlight, .crop]
        for tool in unsupported {
            XCTAssertFalse(tool.supportsBlurRadius, "\(tool) should not support blur radius")
        }
    }

    // MARK: - supportsStartNumber

    func testStartNumberSupportedTools() {
        XCTAssertTrue(AnnotationTool.stepLabel.supportsStartNumber)
    }

    func testStartNumberUnsupportedTools() {
        let unsupported: [AnnotationTool] = [.select, .rectangle, .ellipse, .line, .arrow, .freehand, .text, .speechBubble, .pixelate, .highlight, .obfuscate, .crop]
        for tool in unsupported {
            XCTAssertFalse(tool.supportsStartNumber, "\(tool) should not support start number")
        }
    }
}

@MainActor
final class ToolTypeForAnnotationTests: XCTestCase {

    func testRectangleAnnotationMapsToRectangleTool() {
        let annotation = RectangleAnnotation(bounds: CGRect(x: 0, y: 0, width: 50, height: 50))
        XCTAssertEqual(toolType(for: annotation), .rectangle)
    }

    func testEllipseAnnotationMapsToEllipseTool() {
        let annotation = EllipseAnnotation(bounds: CGRect(x: 0, y: 0, width: 50, height: 50))
        XCTAssertEqual(toolType(for: annotation), .ellipse)
    }

    func testLineAnnotationMapsToLineTool() {
        let annotation = LineAnnotation(bounds: CGRect(x: 0, y: 0, width: 50, height: 50))
        XCTAssertEqual(toolType(for: annotation), .line)
    }

    func testArrowAnnotationMapsToArrowTool() {
        let annotation = ArrowAnnotation(bounds: CGRect(x: 0, y: 0, width: 50, height: 50))
        XCTAssertEqual(toolType(for: annotation), .arrow)
    }

    func testTextAnnotationMapsToTextTool() {
        let annotation = TextAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 30))
        XCTAssertEqual(toolType(for: annotation), .text)
    }

    func testSpeechBubbleMapsToSpeechBubbleTool() {
        let annotation = SpeechBubbleAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 60))
        XCTAssertEqual(toolType(for: annotation), .speechBubble)
    }

    func testStepLabelMapsToStepLabelTool() {
        let annotation = StepLabelAnnotation(center: CGPoint(x: 50, y: 50))
        XCTAssertEqual(toolType(for: annotation), .stepLabel)
    }

    func testPixelateFilterMapsToPixelateTool() {
        let annotation = PixelateFilter(bounds: CGRect(x: 0, y: 0, width: 50, height: 50))
        XCTAssertEqual(toolType(for: annotation), .pixelate)
    }

    func testHighlightFilterMapsToHighlightTool() {
        let annotation = HighlightFilter(bounds: CGRect(x: 0, y: 0, width: 50, height: 50))
        XCTAssertEqual(toolType(for: annotation), .highlight)
    }
}

@MainActor
final class CanvasViewDelegateTests: XCTestCase {

    private final class MockDelegate: CanvasViewDelegate {
        var selectedAnnotation: Annotation?
        var selectedAnnotationCallCount = 0
        var lastTool: AnnotationTool?

        func canvasView(_ canvas: CanvasView, didSelectAnnotation annotation: Annotation?) {
            selectedAnnotation = annotation
            selectedAnnotationCallCount += 1
        }

        func canvasView(_ canvas: CanvasView, didChangeCurrentTool tool: AnnotationTool) {
            lastTool = tool
        }
        func canvasView(_ canvas: CanvasView, mouseMovedTo point: CGPoint) {}
    }

    private func makeCanvas() -> CanvasView {
        let canvas = CanvasView()
        canvas.setupUndoManager()
        let image = NSImage(size: NSSize(width: 400, height: 300))
        canvas.backgroundImage = image
        canvas.frame = CGRect(origin: .zero, size: CGSize(width: 400, height: 300))
        return canvas
    }

    func testDelegateCalledOnSelectAnnotation() {
        let canvas = makeCanvas()
        let delegate = MockDelegate()
        canvas.delegate = delegate

        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        canvas.addAnnotation(rect, isUndoAction: true)
        canvas.selectAnnotation(rect)

        XCTAssertTrue(delegate.selectedAnnotation?.id == rect.id)
        XCTAssertEqual(delegate.selectedAnnotationCallCount, 1)
    }

    func testDelegateCalledOnDeselectAnnotation() {
        let canvas = makeCanvas()
        let delegate = MockDelegate()
        canvas.delegate = delegate

        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        canvas.addAnnotation(rect, isUndoAction: true)
        canvas.selectAnnotation(rect)
        canvas.selectAnnotation(nil)

        XCTAssertNil(delegate.selectedAnnotation)
        XCTAssertEqual(delegate.selectedAnnotationCallCount, 2)
    }

    func testDelegateCalledOnToolChange() {
        let canvas = makeCanvas()
        let delegate = MockDelegate()
        canvas.delegate = delegate

        canvas.currentTool = .rectangle
        XCTAssertEqual(delegate.lastTool, .rectangle)

        canvas.currentTool = .select
        XCTAssertEqual(delegate.lastTool, .select)
    }

    func testSelectedAnnotationAccessible() {
        let canvas = makeCanvas()
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        canvas.addAnnotation(rect, isUndoAction: true)

        XCTAssertNil(canvas.selectedAnnotation)
        canvas.selectAnnotation(rect)
        XCTAssertTrue(canvas.selectedAnnotation?.id == rect.id)
    }
}

@MainActor
final class StyleApplicationTests: XCTestCase {

    func testAnnotationCreatedWithCurrentStyle() {
        var style = AnnotationStyle()
        style.strokeColor = .blue
        style.fillColor = NSColor.green.withAlphaComponent(0.5)
        style.strokeWidth = 5.0

        let rect = RectangleAnnotation(bounds: CGRect(x: 0, y: 0, width: 50, height: 50), style: style)
        XCTAssertEqual(rect.style.strokeColor, .blue)
        XCTAssertEqual(rect.style.fillColor, NSColor.green.withAlphaComponent(0.5))
        XCTAssertEqual(rect.style.strokeWidth, 5.0)
    }

    func testStyleWithAlphaPreserved() {
        var style = AnnotationStyle()
        style.strokeColor = NSColor.red.withAlphaComponent(0.3)
        style.fillColor = NSColor.yellow.withAlphaComponent(0.7)

        let ellipse = EllipseAnnotation(bounds: CGRect(x: 0, y: 0, width: 50, height: 50), style: style)

        // Convert to sRGB for comparison
        let strokeAlpha = ellipse.style.strokeColor.alphaComponent
        let fillAlpha = ellipse.style.fillColor.alphaComponent
        XCTAssertEqual(strokeAlpha, 0.3, accuracy: 0.01)
        XCTAssertEqual(fillAlpha, 0.7, accuracy: 0.01)
    }
}
