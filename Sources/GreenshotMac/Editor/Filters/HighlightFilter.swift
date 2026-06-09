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
            style.strokeWidth = 0
            // A highlight must never be colourless: fall back to the managed
            // highlight colour when no fill is provided.
            if style.fillColor == .clear {
                style.fillColor = Preferences.shared.defaultHighlightColor
            }
            self.style = style
        } else {
            var defaultStyle = AnnotationStyle()
            defaultStyle.fillColor = Preferences.shared.defaultHighlightColor
            defaultStyle.shadow = .none
            self.style = defaultStyle
        }
    }

    func draw(in context: CGContext) {
        context.saveGState()
        context.setAlpha(style.opacity)

        let rect = bounds.standardized
        guard rect.width > 0, rect.height > 0 else {
            context.restoreGState()
            return
        }

        // Use multiply blend mode for realistic highlighter effect
        // Matching Greenshot Windows behavior: colored overlay that darkens underlying content
        context.setBlendMode(.multiply)
        context.setFillColor(style.fillColor.cgColor)
        context.fill(rect)
        context.setBlendMode(.normal)

        context.restoreGState()

        drawSelectionHandles(in: context)
    }

    func copy() -> Annotation {
        let c = HighlightFilter(bounds: bounds, style: style)
        return c
    }
}
