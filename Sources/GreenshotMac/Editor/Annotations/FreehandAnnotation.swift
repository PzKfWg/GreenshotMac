import AppKit

@MainActor
final class FreehandAnnotation: Annotation {
    let id = UUID()
    var bounds: CGRect
    var style: AnnotationStyle
    var isSelected: Bool = false
    var points: [CGPoint]

    init(points: [CGPoint], style: AnnotationStyle = AnnotationStyle()) {
        self.points = points
        self.style = style
        self.bounds = FreehandAnnotation.computeBounds(from: points)
    }

    func draw(in context: CGContext) {
        guard points.count >= 2 else { return }

        context.saveGState()
        context.setAlpha(style.opacity)
        style.shadow.apply(to: context)

        context.setStrokeColor(style.strokeColor.cgColor)
        context.setLineWidth(style.strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        style.dashPattern.apply(to: context)

        context.move(to: points[0])
        for i in 1..<points.count {
            context.addLine(to: points[i])
        }
        context.strokePath()

        context.restoreGState()

        drawSelectionHandles(in: context)
    }

    func hitTest(point: CGPoint) -> Bool {
        let tolerance = max(6.0, style.strokeWidth + 4)
        for i in 1..<points.count {
            if distanceFromPointToLineSegment(point: point, lineStart: points[i - 1], lineEnd: points[i]) <= tolerance {
                return true
            }
        }
        return false
    }

    func copy() -> Annotation {
        FreehandAnnotation(points: points, style: style)
    }

    func addPoint(_ point: CGPoint) {
        points.append(point)
        bounds = FreehandAnnotation.computeBounds(from: points)
    }

    private static func computeBounds(from points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, maxX = first.x
        var minY = first.y, maxY = first.y
        for p in points {
            minX = min(minX, p.x)
            maxX = max(maxX, p.x)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
