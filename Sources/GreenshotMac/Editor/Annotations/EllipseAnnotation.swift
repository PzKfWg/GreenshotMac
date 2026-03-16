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
        context.setAlpha(style.opacity)
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
        style.dashPattern.apply(to: context)
        context.strokeEllipse(in: rect)

        context.restoreGState()

        drawSelectionHandles(in: context)
    }

    /// Ellipse-aware hit test using the ellipse equation x²/a² + y²/b² ≤ 1,
    /// matching Greenshot Windows EllipseContainer.Contains().
    /// For unfilled ellipses, tests proximity to the outline with tolerance.
    func hitTest(point: CGPoint) -> Bool {
        let tolerance: CGFloat = max(4, style.strokeWidth + 4)
        let cx = bounds.midX
        let cy = bounds.midY
        let a = bounds.width / 2 + tolerance
        let b = bounds.height / 2 + tolerance

        guard a > 0 && b > 0 else { return false }

        let dx = point.x - cx
        let dy = point.y - cy
        let normalizedDist = (dx * dx) / (a * a) + (dy * dy) / (b * b)

        if style.fillColor != .clear {
            // Filled: point inside the expanded ellipse
            return normalizedDist <= 1.0
        } else {
            // Outline only: point near the ellipse border
            let aInner = max(0, bounds.width / 2 - tolerance)
            let bInner = max(0, bounds.height / 2 - tolerance)
            let outerDist = normalizedDist
            if aInner > 0 && bInner > 0 {
                let innerDist = (dx * dx) / (aInner * aInner) + (dy * dy) / (bInner * bInner)
                return outerDist <= 1.0 && innerDist >= 1.0
            }
            return outerDist <= 1.0
        }
    }

    func copy() -> Annotation {
        let c = EllipseAnnotation(bounds: bounds, style: style)
        return c
    }
}
