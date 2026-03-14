import XCTest
import AppKit
@testable import GreenshotMac

@MainActor
final class CropToolTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a solid-color NSImage of the given size.
    private func makeImage(width: CGFloat, height: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(origin: .zero, size: image.size).fill()
        image.unlockFocus()
        return image
    }

    // MARK: - crop(image:to:)

    func testCropProducesCorrectDimensions() {
        let image = makeImage(width: 200, height: 100)
        let cropRect = CGRect(x: 10, y: 10, width: 50, height: 40)

        let result = CropTool.crop(image: image, to: cropRect)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.size.width, 50)
        XCTAssertEqual(result?.size.height, 40)
    }

    func testCropWithRectLargerThanImage() {
        let image = makeImage(width: 100, height: 100)
        // Rect extends beyond image boundaries
        let cropRect = CGRect(x: 50, y: 50, width: 200, height: 200)

        // CGImage.cropping(to:) clips to the intersection with image bounds.
        // The result should not be nil since there is partial overlap.
        let result = CropTool.crop(image: image, to: cropRect)
        XCTAssertNotNil(result)
        // The actual pixel content is clipped, but NSImage size is set to cropRect size.
        // This is acceptable behavior - the image will have transparent/black areas outside the original.
    }

    // MARK: - Annotation position adjustment

    func testAnnotationPositionAdjustedAfterCrop() {
        let canvas = CanvasView()
        canvas.setupUndoManager()
        canvas.backgroundImage = makeImage(width: 300, height: 200)
        canvas.frame = CGRect(origin: .zero, size: CGSize(width: 300, height: 200))

        let annotation = RectangleAnnotation(bounds: CGRect(x: 100, y: 80, width: 50, height: 30))
        canvas.addAnnotation(annotation, isUndoAction: true)

        let cropRect = CGRect(x: 50, y: 40, width: 200, height: 120)
        CropTool.applyCrop(to: canvas, rect: cropRect)

        // Annotation origin should be shifted by the crop origin
        XCTAssertEqual(annotation.bounds.origin.x, 50, accuracy: 0.01)  // 100 - 50
        XCTAssertEqual(annotation.bounds.origin.y, 40, accuracy: 0.01)  // 80 - 40
        XCTAssertEqual(annotation.bounds.size.width, 50, accuracy: 0.01)
        XCTAssertEqual(annotation.bounds.size.height, 30, accuracy: 0.01)
    }

    func testAnnotationOutsideCropRectIsRemoved() {
        let canvas = CanvasView()
        canvas.setupUndoManager()
        canvas.backgroundImage = makeImage(width: 300, height: 200)
        canvas.frame = CGRect(origin: .zero, size: CGSize(width: 300, height: 200))

        // This annotation is entirely outside the crop area
        let outsideAnnotation = RectangleAnnotation(bounds: CGRect(x: 10, y: 10, width: 20, height: 20))
        // This annotation is inside the crop area
        let insideAnnotation = RectangleAnnotation(bounds: CGRect(x: 120, y: 80, width: 30, height: 30))

        canvas.addAnnotation(outsideAnnotation, isUndoAction: true)
        canvas.addAnnotation(insideAnnotation, isUndoAction: true)

        let cropRect = CGRect(x: 100, y: 60, width: 150, height: 100)
        CropTool.applyCrop(to: canvas, rect: cropRect)

        // Outside annotation should be removed
        XCTAssertEqual(canvas.annotations.count, 1)
        XCTAssertEqual(canvas.annotations.first?.id, insideAnnotation.id)
    }

    func testCanvasFrameResizedAfterCrop() {
        let canvas = CanvasView()
        canvas.setupUndoManager()
        canvas.backgroundImage = makeImage(width: 400, height: 300)
        canvas.frame = CGRect(origin: .zero, size: CGSize(width: 400, height: 300))

        let cropRect = CGRect(x: 50, y: 50, width: 200, height: 150)
        CropTool.applyCrop(to: canvas, rect: cropRect)

        XCTAssertEqual(canvas.frame.size.width, 200, accuracy: 0.01)
        XCTAssertEqual(canvas.frame.size.height, 150, accuracy: 0.01)
    }
}
