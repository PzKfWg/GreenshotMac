import AppKit

@MainActor
final class PixelateFilter: Annotation {
    let id = UUID()
    var bounds: CGRect
    var style: AnnotationStyle
    var isSelected: Bool = false

    init(bounds: CGRect, style: AnnotationStyle = AnnotationStyle()) {
        self.bounds = bounds
        self.style = style
    }

    func draw(in context: CGContext) {
        context.saveGState()

        let rect = bounds.standardized
        guard rect.width > 0, rect.height > 0 else {
            context.restoreGState()
            return
        }

        // Draw semi-transparent gray overlay to indicate pixelation area
        context.setFillColor(NSColor.gray.withAlphaComponent(0.15).cgColor)
        context.fill(rect)

        // Draw grid of small squares to visually suggest pixelation
        let gridSize: CGFloat = 8
        context.setStrokeColor(style.strokeColor.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(0.5)

        // Vertical grid lines
        var x = rect.minX
        while x <= rect.maxX {
            context.move(to: CGPoint(x: x, y: rect.minY))
            context.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += gridSize
        }

        // Horizontal grid lines
        var y = rect.minY
        while y <= rect.maxY {
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += gridSize
        }

        context.strokePath()

        // Draw dashed border
        context.setStrokeColor(style.strokeColor.cgColor)
        context.setLineWidth(style.strokeWidth)
        context.setLineDash(phase: 0, lengths: [6, 4])
        context.stroke(rect)

        context.restoreGState()

        drawSelectionHandles(in: context)
    }

    func copy() -> Annotation {
        let c = PixelateFilter(bounds: bounds, style: style)
        return c
    }
}
