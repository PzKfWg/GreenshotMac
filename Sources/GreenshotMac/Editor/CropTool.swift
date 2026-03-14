import AppKit

@MainActor
final class CropTool {

    /// Creates a new NSImage cropped to the given rect, handling Retina/scale properly.
    static func crop(image: NSImage, to rect: CGRect) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let scale = CGFloat(cgImage.width) / image.size.width
        let scaledRect = CGRect(x: rect.origin.x * scale, y: rect.origin.y * scale,
                                width: rect.width * scale, height: rect.height * scale)
        guard let cropped = cgImage.cropping(to: scaledRect) else { return nil }
        return NSImage(cgImage: cropped, size: NSSize(width: rect.width, height: rect.height))
    }

    /// Crops the background image, adjusts annotation positions, removes out-of-bounds annotations,
    /// and resizes the canvas frame to match the new image size.
    static func applyCrop(to canvas: CanvasView, rect: CGRect) {
        guard let bgImage = canvas.backgroundImage,
              let croppedImage = crop(image: bgImage, to: rect) else { return }

        canvas.backgroundImage = croppedImage

        // Collect annotations that fall completely outside the new bounds
        let newBounds = CGRect(origin: .zero, size: croppedImage.size)
        var toRemove: [Annotation] = []

        for annotation in canvas.annotations {
            // Shift annotation position by subtracting the crop origin
            var adjusted = annotation.bounds
            adjusted.origin.x -= rect.origin.x
            adjusted.origin.y -= rect.origin.y
            annotation.bounds = adjusted

            // If the annotation is completely outside the new bounds, mark for removal
            if !newBounds.intersects(adjusted) {
                toRemove.append(annotation)
            }
        }

        for annotation in toRemove {
            canvas.removeAnnotation(annotation, isUndoAction: true)
        }

        // Resize the canvas frame to match the new image size
        canvas.frame = CGRect(origin: canvas.frame.origin, size: croppedImage.size)
    }
}
