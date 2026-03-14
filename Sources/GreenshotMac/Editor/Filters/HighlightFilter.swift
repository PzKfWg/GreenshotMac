import AppKit

@MainActor
final class HighlightFilter: Annotation {
    let id = UUID()
    var bounds: CGRect
    var style: AnnotationStyle
    var isSelected: Bool = false

    init(bounds: CGRect, style: AnnotationStyle? = nil) {
        self.bounds = bounds
        if var style {
            // Spec §5.2: shadow is always disabled on highlights
            style.shadow = .none
            self.style = style
        } else {
            var defaultStyle = AnnotationStyle()
            defaultStyle.fillColor = NSColor.yellow.withAlphaComponent(0.4)
            defaultStyle.shadow = .none
            self.style = defaultStyle
        }
    }

    func draw(in context: CGContext) {
        context.saveGState()

        let rect = bounds.standardized
        guard rect.width > 0, rect.height > 0 else {
            context.restoreGState()
            return
        }

        // No shadow for highlights — it would look wrong
        // Draw semi-transparent colored rectangle (highlighter effect)
        context.setFillColor(style.fillColor.cgColor)
        context.fill(rect)

        context.restoreGState()

        drawSelectionHandles(in: context)
    }

    func copy() -> Annotation {
        let c = HighlightFilter(bounds: bounds, style: style)
        return c
    }
}
