import AppKit

@MainActor
final class LineAnnotation: Annotation {
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
        context.setAlpha(style.opacity)
        style.shadow.apply(to: context)

        context.setStrokeColor(style.strokeColor.cgColor)
        context.setLineWidth(style.strokeWidth)
        context.setLineCap(.round)
        style.dashPattern.apply(to: context)

        context.move(to: startPoint)
        context.addLine(to: endPoint)
        context.strokePath()

        context.restoreGState()

        drawSelectionHandles(in: context)
    }

    /// Hit test with tolerance that scales with stroke width,
    /// matching Greenshot Windows LineContainer (lineThickness + 5).
    func hitTest(point: CGPoint) -> Bool {
        let tolerance = max(6.0, style.strokeWidth + 5)
        return distanceFromPointToLineSegment(point: point, lineStart: startPoint, lineEnd: endPoint) <= tolerance
    }

    func copy() -> Annotation {
        LineAnnotation(bounds: bounds, style: style, direction: direction)
    }
}
