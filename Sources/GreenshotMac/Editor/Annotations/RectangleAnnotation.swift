import AppKit

@MainActor
final class RectangleAnnotation: Annotation {
    let id = UUID()
    var bounds: CGRect
    var style: AnnotationStyle
    var isSelected: Bool = false
    var cornerRadius: CGFloat

    init(bounds: CGRect, style: AnnotationStyle = AnnotationStyle(), cornerRadius: CGFloat = 0) {
        self.bounds = bounds
        self.style = style
        self.cornerRadius = cornerRadius
    }

    func draw(in context: CGContext) {
        context.saveGState()
        context.setAlpha(style.opacity)
        style.shadow.apply(to: context)

        let rect = bounds
        let path: CGPath
        if cornerRadius > 0 {
            let effectiveRadius = min(cornerRadius, min(rect.width, rect.height) / 2)
            path = CGPath(roundedRect: rect, cornerWidth: effectiveRadius, cornerHeight: effectiveRadius, transform: nil)
        } else {
            path = CGPath(rect: rect, transform: nil)
        }

        // Fill
        if style.fillColor != .clear {
            context.setFillColor(style.fillColor.cgColor)
            context.addPath(path)
            context.fillPath()
        }

        // Stroke
        context.setStrokeColor(style.strokeColor.cgColor)
        context.setLineWidth(style.strokeWidth)
        style.dashPattern.apply(to: context)
        context.addPath(path)
        context.strokePath()

        context.restoreGState()

        drawSelectionHandles(in: context)
    }

    func copy() -> Annotation {
        let c = RectangleAnnotation(bounds: bounds, style: style, cornerRadius: cornerRadius)
        return c
    }
}
