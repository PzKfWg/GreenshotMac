import AppKit

@MainActor
final class ArrowAnnotation: Annotation {
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

        // Draw line
        context.move(to: startPoint)
        context.addLine(to: endPoint)
        context.strokePath()

        // Draw arrowhead
        drawArrowhead(in: context)

        context.restoreGState()

        drawSelectionHandles(in: context)
    }

    func hitTest(point: CGPoint) -> Bool {
        let tolerance: CGFloat = 6.0
        return distanceFromPointToLine(point: point, lineStart: startPoint, lineEnd: endPoint) <= tolerance
    }

    func copy() -> Annotation {
        ArrowAnnotation(bounds: bounds, style: style)
    }

    // MARK: - Private

    private func drawArrowhead(in context: CGContext) {
        let angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)
        let arrowLength = 10 + style.strokeWidth * 2
        let arrowAngle: CGFloat = .pi / 6  // 30 degrees

        let point1 = CGPoint(
            x: endPoint.x - arrowLength * cos(angle - arrowAngle),
            y: endPoint.y - arrowLength * sin(angle - arrowAngle)
        )
        let point2 = CGPoint(
            x: endPoint.x - arrowLength * cos(angle + arrowAngle),
            y: endPoint.y - arrowLength * sin(angle + arrowAngle)
        )

        context.setFillColor(style.strokeColor.cgColor)
        context.move(to: endPoint)
        context.addLine(to: point1)
        context.addLine(to: point2)
        context.closePath()
        context.fillPath()
    }

    private func distanceFromPointToLine(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lengthSquared = dx * dx + dy * dy

        if lengthSquared == 0 {
            let px = point.x - lineStart.x
            let py = point.y - lineStart.y
            return sqrt(px * px + py * py)
        }

        var t = ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / lengthSquared
        t = max(0, min(1, t))

        let closestX = lineStart.x + t * dx
        let closestY = lineStart.y + t * dy

        let distX = point.x - closestX
        let distY = point.y - closestY
        return sqrt(distX * distX + distY * distY)
    }
}
