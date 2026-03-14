import AppKit

@MainActor
final class ArrowAnnotation: Annotation {
    let id = UUID()
    var bounds: CGRect
    var style: AnnotationStyle
    var isSelected: Bool = false
    var direction: DiagonalDirection
    var arrowHeads: ArrowHeadCombination

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

    /// Arrowhead dimensions proportional to stroke width, matching Greenshot Windows
    /// AdjustableArrowCap(4, 6): width = 4 * strokeWidth, height = 6 * strokeWidth
    private var arrowCapWidth: CGFloat { 4 * style.strokeWidth }
    private var arrowCapHeight: CGFloat { 6 * style.strokeWidth }

    init(bounds: CGRect, style: AnnotationStyle = AnnotationStyle(), direction: DiagonalDirection = .topLeftToBottomRight, arrowHeads: ArrowHeadCombination = .endPoint) {
        self.bounds = bounds
        self.style = style
        self.direction = direction
        self.arrowHeads = arrowHeads
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

        // Draw arrowheads
        context.setFillColor(style.strokeColor.cgColor)
        if arrowHeads == .endPoint || arrowHeads == .both {
            drawArrowhead(in: context, at: endPoint, towards: startPoint)
        }
        if arrowHeads == .startPoint || arrowHeads == .both {
            drawArrowhead(in: context, at: startPoint, towards: endPoint)
        }

        context.restoreGState()

        drawSelectionHandles(in: context)
    }

    func hitTest(point: CGPoint) -> Bool {
        let tolerance: CGFloat = max(6.0, style.strokeWidth + 4)

        // Test against the line segment
        if distanceFromPointToLineSegment(point: point, lineStart: startPoint, lineEnd: endPoint) <= tolerance {
            return true
        }

        // Test against arrowhead triangles
        if arrowHeads == .endPoint || arrowHeads == .both {
            if pointInArrowhead(point: point, tip: endPoint, towards: startPoint) {
                return true
            }
        }
        if arrowHeads == .startPoint || arrowHeads == .both {
            if pointInArrowhead(point: point, tip: startPoint, towards: endPoint) {
                return true
            }
        }

        return false
    }

    func copy() -> Annotation {
        ArrowAnnotation(bounds: bounds, style: style, direction: direction, arrowHeads: arrowHeads)
    }

    // MARK: - Arrowhead geometry

    /// Returns the two base points of the arrowhead triangle at `tip`, pointing away from `towards`.
    func arrowheadPoints(tip: CGPoint, towards: CGPoint) -> (CGPoint, CGPoint) {
        let angle = atan2(tip.y - towards.y, tip.x - towards.x)
        let halfWidth = arrowCapWidth / 2
        let height = arrowCapHeight
        let baseAngle = atan2(halfWidth, height)

        let len = sqrt(halfWidth * halfWidth + height * height)
        let p1 = CGPoint(
            x: tip.x - len * cos(angle - baseAngle),
            y: tip.y - len * sin(angle - baseAngle)
        )
        let p2 = CGPoint(
            x: tip.x - len * cos(angle + baseAngle),
            y: tip.y - len * sin(angle + baseAngle)
        )
        return (p1, p2)
    }

    // MARK: - Private

    private func drawArrowhead(in context: CGContext, at tip: CGPoint, towards: CGPoint) {
        let (p1, p2) = arrowheadPoints(tip: tip, towards: towards)
        context.move(to: tip)
        context.addLine(to: p1)
        context.addLine(to: p2)
        context.closePath()
        context.fillPath()
    }

    private func pointInArrowhead(point: CGPoint, tip: CGPoint, towards: CGPoint) -> Bool {
        let (p1, p2) = arrowheadPoints(tip: tip, towards: towards)
        return pointInTriangle(p: point, v1: tip, v2: p1, v3: p2)
    }

    private func pointInTriangle(p: CGPoint, v1: CGPoint, v2: CGPoint, v3: CGPoint) -> Bool {
        let d1 = sign(p: p, a: v1, b: v2)
        let d2 = sign(p: p, a: v2, b: v3)
        let d3 = sign(p: p, a: v3, b: v1)
        let hasNeg = (d1 < 0) || (d2 < 0) || (d3 < 0)
        let hasPos = (d1 > 0) || (d2 > 0) || (d3 > 0)
        return !(hasNeg && hasPos)
    }

    private func sign(p: CGPoint, a: CGPoint, b: CGPoint) -> CGFloat {
        (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y)
    }
}
