import AppKit

@MainActor
final class EllipseAnnotation: Annotation {
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
        style.shadow.apply(to: context)

        let rect = bounds

        // Fill
        if style.fillColor != .clear {
            context.setFillColor(style.fillColor.cgColor)
            context.fillEllipse(in: rect)
        }

        // Stroke
        context.setStrokeColor(style.strokeColor.cgColor)
        context.setLineWidth(style.strokeWidth)
        context.strokeEllipse(in: rect)

        context.restoreGState()

        drawSelectionHandles(in: context)
    }

    func copy() -> Annotation {
        let c = EllipseAnnotation(bounds: bounds, style: style)
        return c
    }
}
