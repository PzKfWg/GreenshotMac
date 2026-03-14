import AppKit

@MainActor
final class LineAnnotation: Annotation {
    let id = UUID()
    var bounds: CGRect
    var style: AnnotationStyle
    var isSelected: Bool = false

    var startPoint: CGPoint { CGPoint(x: bounds.minX, y: bounds.minY) }
    var endPoint: CGPoint { CGPoint(x: bounds.maxX, y: bounds.maxY) }

    init(bounds: CGRect, style: AnnotationStyle = AnnotationStyle()) {
        self.bounds = bounds
        self.style = style
    }

    func draw(in context: CGContext) {
        context.saveGState()
        style.shadow.apply(to: context)

        context.setStrokeColor(style.strokeColor.cgColor)
        context.setLineWidth(style.strokeWidth)
        context.setLineCap(.round)

        context.move(to: startPoint)
        context.addLine(to: endPoint)
        context.strokePath()

        context.restoreGState()

        drawSelectionHandles(in: context)
    }

    func hitTest(point: CGPoint) -> Bool {
        let tolerance: CGFloat = 6.0
        return distanceFromPointToLine(point: point, lineStart: startPoint, lineEnd: endPoint) <= tolerance
    }

    func copy() -> Annotation {
        LineAnnotation(bounds: bounds, style: style)
    }

    // MARK: - Private

    private func distanceFromPointToLine(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lengthSquared = dx * dx + dy * dy

        if lengthSquared == 0 {
            // Line is a point
            let px = point.x - lineStart.x
            let py = point.y - lineStart.y
            return sqrt(px * px + py * py)
        }

        // Parameter t of the closest point on the segment
        var t = ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / lengthSquared
        t = max(0, min(1, t))

        let closestX = lineStart.x + t * dx
        let closestY = lineStart.y + t * dy

        let distX = point.x - closestX
        let distY = point.y - closestY
        return sqrt(distX * distX + distY * distY)
    }
}
