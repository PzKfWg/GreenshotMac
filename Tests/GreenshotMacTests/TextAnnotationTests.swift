import XCTest
import AppKit
@testable import GreenshotMac

@MainActor
final class TextAnnotationTests: XCTestCase {

    func testInitWithDefaultText() {
        let annotation = TextAnnotation(bounds: CGRect(x: 10, y: 20, width: 200, height: 50))
        XCTAssertEqual(annotation.text, "Texte")
        XCTAssertEqual(annotation.bounds, CGRect(x: 10, y: 20, width: 200, height: 50))
        XCTAssertFalse(annotation.isSelected)
    }

    func testHitTestInsideBounds() {
        let annotation = TextAnnotation(bounds: CGRect(x: 10, y: 20, width: 200, height: 50))
        XCTAssertTrue(annotation.hitTest(point: CGPoint(x: 100, y: 40)))
    }

    func testHitTestOutsideBounds() {
        let annotation = TextAnnotation(bounds: CGRect(x: 10, y: 20, width: 200, height: 50))
        XCTAssertFalse(annotation.hitTest(point: CGPoint(x: 300, y: 300)))
    }

    func testCopyPreservesText() {
        let original = TextAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 40), text: "Hello")
        let copy = original.copy()
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertEqual(copy.bounds, original.bounds)
        guard let textCopy = copy as? TextAnnotation else {
            XCTFail("Copy should be a TextAnnotation")
            return
        }
        XCTAssertEqual(textCopy.text, "Hello")
    }

    func testCustomStylePreserved() {
        var style = AnnotationStyle()
        style.strokeColor = .blue
        style.fontSize = 24.0
        style.fontName = "Courier"
        style.shadow = .none
        let annotation = TextAnnotation(bounds: .zero, style: style)
        XCTAssertEqual(annotation.style.fontSize, 24.0)
        XCTAssertEqual(annotation.style.fontName, "Courier")
        XCTAssertFalse(annotation.style.shadow.enabled)
    }

    // MARK: - Bold/Italic (aligned with Greenshot Windows TextContainer)

    func testDefaultStyleHasNoBoldOrItalic() {
        let annotation = TextAnnotation(bounds: .zero)
        XCTAssertFalse(annotation.style.fontBold)
        XCTAssertFalse(annotation.style.fontItalic)
    }

    func testResolveFontWithBold() {
        var style = AnnotationStyle()
        style.fontBold = true
        let annotation = TextAnnotation(bounds: .zero, style: style)
        let font = annotation.resolveFont()
        let traits = NSFontManager.shared.traits(of: font)
        XCTAssertTrue(traits.contains(.boldFontMask), "Font should have bold trait")
    }

    func testResolveFontWithItalic() {
        var style = AnnotationStyle()
        style.fontItalic = true
        let annotation = TextAnnotation(bounds: .zero, style: style)
        let font = annotation.resolveFont()
        let traits = NSFontManager.shared.traits(of: font)
        XCTAssertTrue(traits.contains(.italicFontMask), "Font should have italic trait")
    }

    func testResolveFontWithBoldAndItalic() {
        var style = AnnotationStyle()
        style.fontBold = true
        style.fontItalic = true
        let annotation = TextAnnotation(bounds: .zero, style: style)
        let font = annotation.resolveFont()
        let traits = NSFontManager.shared.traits(of: font)
        XCTAssertTrue(traits.contains(.boldFontMask), "Font should have bold trait")
        XCTAssertTrue(traits.contains(.italicFontMask), "Font should have italic trait")
    }

    func testResolveFontFallsBackToSystemFont() {
        var style = AnnotationStyle()
        style.fontName = "NonExistentFont12345"
        let annotation = TextAnnotation(bounds: .zero, style: style)
        let font = annotation.resolveFont()
        XCTAssertNotNil(font, "Should fallback to system font")
        XCTAssertEqual(font.pointSize, style.fontSize)
    }

    // MARK: - Text alignment (aligned with Greenshot Windows TextContainer)

    func testDefaultAlignmentIsCenterCenter() {
        let annotation = TextAnnotation(bounds: .zero)
        XCTAssertEqual(annotation.style.textHorizontalAlignment, .center)
        XCTAssertEqual(annotation.style.textVerticalAlignment, .center)
    }

    func testHorizontalAlignmentLeft() {
        var style = AnnotationStyle()
        style.textHorizontalAlignment = .left
        let annotation = TextAnnotation(bounds: .zero, style: style)
        XCTAssertEqual(annotation.style.textHorizontalAlignment, .left)
    }

    func testHorizontalAlignmentRight() {
        var style = AnnotationStyle()
        style.textHorizontalAlignment = .right
        let annotation = TextAnnotation(bounds: .zero, style: style)
        XCTAssertEqual(annotation.style.textHorizontalAlignment, .right)
    }

    func testVerticalAlignmentTop() {
        var style = AnnotationStyle()
        style.textVerticalAlignment = .top
        let annotation = TextAnnotation(bounds: .zero, style: style)
        XCTAssertEqual(annotation.style.textVerticalAlignment, .top)
    }

    func testVerticalAlignmentBottom() {
        var style = AnnotationStyle()
        style.textVerticalAlignment = .bottom
        let annotation = TextAnnotation(bounds: .zero, style: style)
        XCTAssertEqual(annotation.style.textVerticalAlignment, .bottom)
    }

    func testCopyPreservesAlignmentAndFontTraits() {
        var style = AnnotationStyle()
        style.fontBold = true
        style.textHorizontalAlignment = .right
        style.textVerticalAlignment = .bottom
        let original = TextAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 40), style: style, text: "Test")
        guard let copy = original.copy() as? TextAnnotation else {
            XCTFail("Copy should be TextAnnotation")
            return
        }
        XCTAssertTrue(copy.style.fontBold)
        XCTAssertEqual(copy.style.textHorizontalAlignment, .right)
        XCTAssertEqual(copy.style.textVerticalAlignment, .bottom)
        XCTAssertEqual(copy.text, "Test")
    }
}
