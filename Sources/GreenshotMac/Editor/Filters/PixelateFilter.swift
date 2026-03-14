import AppKit
import CoreImage

@MainActor
final class PixelateFilter: Annotation {
    let id = UUID()
    var bounds: CGRect
    var style: AnnotationStyle
    var isSelected: Bool = false
    var pixelSize: Int = 5
    weak var backgroundImage: NSImage?

    private static let ciContext = CIContext()

    init(bounds: CGRect, style: AnnotationStyle = AnnotationStyle()) {
        self.bounds = bounds
        self.style = style
    }

    func draw(in context: CGContext) {
        let rect = bounds.standardized
        guard rect.width > 0, rect.height > 0 else { return }

        if let bgImage = backgroundImage, pixelSize > 1 {
            drawPixelated(in: context, rect: rect, bgImage: bgImage)
        } else {
            drawPlaceholder(in: context, rect: rect)
        }

        // Dashed border indicator
        context.saveGState()
        context.setStrokeColor(NSColor.gray.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [6, 4])
        context.stroke(rect)
        context.restoreGState()

        drawSelectionHandles(in: context)
    }

    private func drawPixelated(in context: CGContext, rect: CGRect, bgImage: NSImage) {
        // Adapt pixelSize to bounds (like C# reference)
        var effectiveSize = pixelSize
        if Int(rect.width) < effectiveSize { effectiveSize = max(1, Int(rect.width)) }
        if Int(rect.height) < effectiveSize { effectiveSize = max(1, Int(rect.height)) }
        guard effectiveSize > 1 else { return }

        // Get CGImage from NSImage
        guard let cgImage = bgImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            drawPlaceholder(in: context, rect: rect)
            return
        }

        let imageSize = bgImage.size
        // Convert from flipped coordinates to CGImage coordinates (origin bottom-left)
        let cropRect = CGRect(
            x: rect.origin.x,
            y: imageSize.height - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        ).intersection(CGRect(origin: .zero, size: imageSize))

        guard cropRect.width > 0, cropRect.height > 0,
              let croppedCG = cgImage.cropping(to: cropRect) else {
            drawPlaceholder(in: context, rect: rect)
            return
        }

        let ciImage = CIImage(cgImage: croppedCG)

        guard let filter = CIFilter(name: "CIPixellate") else {
            drawPlaceholder(in: context, rect: rect)
            return
        }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(NSNumber(value: effectiveSize), forKey: kCIInputScaleKey)
        // Center the pixelation grid
        filter.setValue(CIVector(x: CGFloat(effectiveSize) / 2, y: CGFloat(effectiveSize) / 2), forKey: kCIInputCenterKey)

        guard let output = filter.outputImage else {
            drawPlaceholder(in: context, rect: rect)
            return
        }

        // Crop output to original extent (CIPixellate may expand)
        let croppedOutput = output.cropped(to: ciImage.extent)

        guard let resultCG = Self.ciContext.createCGImage(croppedOutput, from: croppedOutput.extent) else {
            drawPlaceholder(in: context, rect: rect)
            return
        }

        // Draw in flipped coordinate context
        context.saveGState()
        context.clip(to: rect)
        // CGContext.draw draws with origin at bottom-left, but we're in a flipped context
        // so we need to flip just for this image
        context.translateBy(x: rect.origin.x, y: rect.origin.y + rect.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(resultCG, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }

    private func drawPlaceholder(in context: CGContext, rect: CGRect) {
        context.saveGState()
        context.setFillColor(NSColor.gray.withAlphaComponent(0.15).cgColor)
        context.fill(rect)

        let gridSize: CGFloat = 8
        context.setStrokeColor(NSColor.gray.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(0.5)

        var x = rect.minX
        while x <= rect.maxX {
            context.move(to: CGPoint(x: x, y: rect.minY))
            context.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += gridSize
        }
        var y = rect.minY
        while y <= rect.maxY {
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += gridSize
        }
        context.strokePath()
        context.restoreGState()
    }

    func copy() -> Annotation {
        let c = PixelateFilter(bounds: bounds, style: style)
        c.pixelSize = pixelSize
        return c
    }
}
