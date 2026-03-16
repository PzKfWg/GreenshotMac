import AppKit
import CoreImage

@MainActor
final class ObfuscateFilter: Annotation {
    let id = UUID()
    var bounds: CGRect
    var style: AnnotationStyle
    var isSelected: Bool = false
    var blurRadius: Int = 10
    weak var backgroundImage: NSImage?

    private static let ciContext = CIContext()

    init(bounds: CGRect, style: AnnotationStyle = AnnotationStyle()) {
        self.bounds = bounds
        self.style = style
    }

    func draw(in context: CGContext) {
        let rect = bounds.standardized
        guard rect.width > 0, rect.height > 0 else { return }

        if let bgImage = backgroundImage, blurRadius > 0 {
            drawBlurred(in: context, rect: rect, bgImage: bgImage)
        } else {
            drawPlaceholder(in: context, rect: rect)
        }

        if isSelected {
            context.saveGState()
            context.setStrokeColor(NSColor.gray.withAlphaComponent(0.6).cgColor)
            context.setLineWidth(1)
            context.setLineDash(phase: 0, lengths: [6, 4])
            context.stroke(rect)
            context.restoreGState()
        }

        drawSelectionHandles(in: context)
    }

    private func drawBlurred(in context: CGContext, rect: CGRect, bgImage: NSImage) {
        guard let cgImage = bgImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            drawPlaceholder(in: context, rect: rect)
            return
        }

        let imageSize = bgImage.size
        let scaleX = CGFloat(cgImage.width) / imageSize.width
        let scaleY = CGFloat(cgImage.height) / imageSize.height

        // Use CIImage for the full pipeline — CIImage uses bottom-left origin (well-documented)
        let fullCI = CIImage(cgImage: cgImage)
        let ciCropRect = CGRect(
            x: rect.origin.x * scaleX,
            y: (imageSize.height - rect.origin.y - rect.height) * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        ).intersection(fullCI.extent)

        guard ciCropRect.width > 0, ciCropRect.height > 0 else {
            drawPlaceholder(in: context, rect: rect)
            return
        }

        let croppedCI = fullCI.cropped(to: ciCropRect)

        guard let filter = CIFilter(name: "CIGaussianBlur") else {
            drawPlaceholder(in: context, rect: rect)
            return
        }
        filter.setValue(croppedCI, forKey: kCIInputImageKey)
        filter.setValue(NSNumber(value: blurRadius), forKey: kCIInputRadiusKey)

        guard let output = filter.outputImage else {
            drawPlaceholder(in: context, rect: rect)
            return
        }

        let croppedOutput = output.cropped(to: ciCropRect)

        guard let resultCG = Self.ciContext.createCGImage(croppedOutput, from: ciCropRect) else {
            drawPlaceholder(in: context, rect: rect)
            return
        }

        // Draw in flipped coordinate context
        context.saveGState()
        context.clip(to: rect)
        context.translateBy(x: rect.origin.x, y: rect.origin.y + rect.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(resultCG, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }

    private func drawPlaceholder(in context: CGContext, rect: CGRect) {
        context.saveGState()
        context.setFillColor(NSColor.gray.withAlphaComponent(0.2).cgColor)
        context.fill(rect)
        context.restoreGState()
    }

    func hitTest(point: CGPoint) -> Bool {
        bounds.insetBy(dx: -4, dy: -4).contains(point)
    }

    func copy() -> Annotation {
        let c = ObfuscateFilter(bounds: bounds, style: style)
        c.blurRadius = blurRadius
        return c
    }
}
