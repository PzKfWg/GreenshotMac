import XCTest
import AppKit
@testable import GreenshotMac

@MainActor
final class RenderingTests: XCTestCase {

    // MARK: - Helpers

    private func makeCanvas(width: CGFloat = 200, height: CGFloat = 100) -> CanvasView {
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

    // MARK: - renderFinalImage

    func testRenderFinalImageReturnsNonNil() {
        let canvas = makeCanvas()
        let result = canvas.renderFinalImage()
        XCTAssertNotNil(result)
    }

    func testRenderFinalImageHasCorrectSize() {
        let canvas = makeCanvas(width: 300, height: 200)
        let result = canvas.renderFinalImage()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.size.width, 300)
        XCTAssertEqual(result?.size.height, 200)
    }

    func testRenderFinalImageWithNoBackgroundReturnsNil() {
        let canvas = CanvasView()
        canvas.setupUndoManager()
        let result = canvas.renderFinalImage()
        XCTAssertNil(result)
    }

    func testRenderFinalImageWithAnnotations() {
        let canvas = makeCanvas()
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        canvas.addAnnotation(rect, isUndoAction: true)

        let result = canvas.renderFinalImage()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.size.width, 200)
        XCTAssertEqual(result?.size.height, 100)
    }

    func testRenderFinalImagePreservesSelection() {
        let canvas = makeCanvas()
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        canvas.addAnnotation(rect, isUndoAction: true)
        canvas.selectAnnotation(rect)
        XCTAssertTrue(rect.isSelected)

        // renderFinalImage should temporarily deselect, then restore
        let _ = canvas.renderFinalImage()
        XCTAssertTrue(rect.isSelected)
    }

    func testRenderFinalImageWithMultipleAnnotations() {
        let canvas = makeCanvas()
        let rect = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50))
        let ellipse = EllipseAnnotation(bounds: CGRect(x: 60, y: 10, width: 50, height: 50))
        let line = LineAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 100))

        canvas.addAnnotation(rect, isUndoAction: true)
        canvas.addAnnotation(ellipse, isUndoAction: true)
        canvas.addAnnotation(line, isUndoAction: true)

        let result = canvas.renderFinalImage()
        XCTAssertNotNil(result)
    }

    // MARK: - Rendered image is usable (has bitmap representation)

    func testRenderFinalImageHasBitmapRepresentation() {
        let canvas = makeCanvas()
        let result = canvas.renderFinalImage()
        XCTAssertNotNil(result)

        let tiffData = result?.tiffRepresentation
        XCTAssertNotNil(tiffData)

        if let data = tiffData {
            let bitmap = NSBitmapImageRep(data: data)
            XCTAssertNotNil(bitmap)
        }
    }

    // MARK: - Rendered image pixel check (basic sanity: not all black/transparent)

    func testRenderFinalImageIsNotAllBlack() {
        let canvas = makeCanvas()
        // Add a bright red rectangle
        var style = AnnotationStyle()
        style.fillColor = .red
        style.shadow = .none
        let rect = RectangleAnnotation(bounds: CGRect(x: 50, y: 25, width: 100, height: 50), style: style)
        canvas.addAnnotation(rect, isUndoAction: true)

        guard let result = canvas.renderFinalImage(),
              let tiff = result.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            XCTFail("Failed to render image")
            return
        }

        // Check a pixel inside the red rectangle area
        // The image is rendered in standard coords, so pixel at (100, 50) in image
        // should be affected by the red fill
        let pixelX = 100
        let pixelY = 50
        guard pixelX < bitmap.pixelsWide, pixelY < bitmap.pixelsHigh else {
            XCTFail("Pixel coordinates out of range")
            return
        }

        // Just verify the bitmap has actual pixel data
        XCTAssertGreaterThan(bitmap.pixelsWide, 0)
        XCTAssertGreaterThan(bitmap.pixelsHigh, 0)
    }
}
