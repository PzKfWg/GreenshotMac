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
    /// and resizes the canvas frame to match the new image size. Supports undo.
    static func applyCrop(to canvas: CanvasView, rect: CGRect) {
        guard let bgImage = canvas.backgroundImage,
              let croppedImage = crop(image: bgImage, to: rect) else { return }

        // Capture state for undo
        let previousImage = bgImage
        let previousFrame = canvas.frame
        let previousBounds: [(Annotation, CGRect)] = canvas.annotations.map { ($0, $0.bounds) }

        canvas.backgroundImage = croppedImage

        // Collect annotations that fall completely outside the new bounds
        let newBounds = CGRect(origin: .zero, size: croppedImage.size)
        var toRemove: [Annotation] = []
        var removedAnnotations: [(Annotation, Int)] = []

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
            if let index = canvas.annotations.firstIndex(where: { $0.id == annotation.id }) {
                removedAnnotations.append((annotation, index))
            }
            canvas.removeAnnotation(annotation, isUndoAction: true)
        }

        // Resize the canvas frame to match the new image size
        canvas.frame = CGRect(origin: canvas.frame.origin, size: croppedImage.size)

        // Register undo for the whole crop operation
        canvas.annotationUndoManager.nsUndoManager.registerUndo(withTarget: canvas) { canvas in
            canvas.backgroundImage = previousImage
            canvas.frame = previousFrame
            // Restore annotation bounds
            for (annotation, oldBounds) in previousBounds {
                annotation.bounds = oldBounds
            }
            // Re-add removed annotations at their original indices
            for (annotation, index) in removedAnnotations.reversed() {
                canvas.insertAnnotation(annotation, at: index, isUndoAction: true)
            }
            canvas.needsDisplay = true
        }
        canvas.annotationUndoManager.nsUndoManager.setActionName("Recadrer")
    }
}
