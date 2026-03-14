import AppKit

@MainActor
final class ArrowAnnotation: Annotation {
    let id = UUID()
    var bounds: CGRect
    var style: AnnotationStyle
    var isSelected: Bool = false
    var direction: DiagonalDirection

    var startPoint: CGPoint {
        switch direction {
        case .topLeftToBottomRight: return CGPoint(x: bounds.minX, y: bounds.minY)
        case .bottomLeftToTopRight: return CGPoint(x: bounds.minX, y: bounds.maxY)
        case .bottomRightToTopLeft: return CGPoint(x: bounds.maxX, y: bounds.maxY)
        case .topRightToBottomLeft: return CGPoint(x: bounds.maxX, y: bounds.minY)
        }
    }

    var endPoint: CGPoint {
        switch direction {
        case .topLeftToBottomRight: return CGPoint(x: bounds.maxX, y: bounds.maxY)
        case .bottomLeftToTopRight: return CGPoint(x: bounds.maxX, y: bounds.minY)
        case .bottomRightToTopLeft: return CGPoint(x: bounds.minX, y: bounds.minY)
        case .topRightToBottomLeft: return CGPoint(x: bounds.minX, y: bounds.maxY)
        }
    }

    init(bounds: CGRect, style: AnnotationStyle = AnnotationStyle(), direction: DiagonalDirection = .topLeftToBottomRight) {
        self.bounds = bounds
        self.style = style
        self.direction = direction
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
        return distanceFromPointToLineSegment(point: point, lineStart: startPoint, lineEnd: endPoint) <= tolerance
    }

    func copy() -> Annotation {
        ArrowAnnotation(bounds: bounds, style: style, direction: direction)
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
}
