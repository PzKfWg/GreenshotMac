import AppKit

enum AnnotationTool: String, CaseIterable, Sendable {
    case select
    case rectangle
    case ellipse
    case line
    case arrow
    case text
    case speechBubble
    case stepLabel
    case pixelate
    case highlight
    case crop

    var supportsStrokeColor: Bool {
        switch self {
        case .rectangle, .ellipse, .line, .arrow, .text, .speechBubble:
            return true
        default:
            return false
        }
    }

    var supportsFillColor: Bool {
        switch self {
        case .rectangle, .ellipse, .speechBubble:
            return true
        default:
            return false
        }
    }

    var supportsStrokeWidth: Bool {
        switch self {
        case .rectangle, .ellipse, .line, .arrow, .speechBubble:
            return true
        default:
            return false
        }
    }

    var supportsShadow: Bool {
        switch self {
        case .rectangle, .ellipse, .line, .arrow, .text, .speechBubble, .stepLabel:
            return true
        default:
            return false
        }
    }

    var supportsPixelSize: Bool {
        self == .pixelate
    }

    var supportsStartNumber: Bool {
        self == .stepLabel
    }
}

enum ArrowHeadCombination: Sendable {
    case none
    case startPoint
    case endPoint
    case both
}

enum DiagonalDirection: Sendable {
    case topLeftToBottomRight
    case bottomLeftToTopRight
    case bottomRightToTopLeft
    case topRightToBottomLeft

    static func from(start: CGPoint, end: CGPoint) -> DiagonalDirection {
        let goingRight = end.x >= start.x
        let goingDown = end.y >= start.y
        switch (goingRight, goingDown) {
        case (true, true):   return .topLeftToBottomRight
        case (true, false):  return .bottomLeftToTopRight
        case (false, true):  return .topRightToBottomLeft
        case (false, false): return .bottomRightToTopLeft
        }
    }
}

func distanceFromPointToLineSegment(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
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

struct AnnotationStyle: Equatable {
    var strokeColor: NSColor = .systemRed
    var fillColor: NSColor = .clear
    var strokeWidth: CGFloat = 2.0
    var fontSize: CGFloat = 14.0
    var fontName: String = "Helvetica"
    var shadow: ShadowStyle = .default
}

@MainActor
protocol Annotation: AnyObject {
    var id: UUID { get }
    var bounds: CGRect { get set }
    var style: AnnotationStyle { get set }
    var isSelected: Bool { get set }

    func draw(in context: CGContext)
    func hitTest(point: CGPoint) -> Bool
    func handleHitTest(point: CGPoint) -> HandlePosition?
    func copy() -> Annotation
}

extension Annotation {
    func hitTest(point: CGPoint) -> Bool {
        let hitArea = bounds.insetBy(dx: -4, dy: -4)
        return hitArea.contains(point)
    }

    func handleHitTest(point: CGPoint) -> HandlePosition? {
        for position in HandlePosition.allCases {
            let handleRect = handleRect(for: position)
            if handleRect.contains(point) {
                return position
            }
        }
        return nil
    }

    func handleRect(for position: HandlePosition) -> CGRect {
        let size: CGFloat = 8
        let point = position.point(in: bounds)
        return CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)
    }

    func drawSelectionHandles(in context: CGContext) {
        guard isSelected else { return }

        // Dashed selection border
        context.saveGState()
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [4, 4])
        context.stroke(bounds)
        context.restoreGState()

        // Handles
        for position in HandlePosition.allCases {
            let rect = handleRect(for: position)
            context.saveGState()
            context.setFillColor(NSColor.white.cgColor)
            context.setStrokeColor(NSColor.controlAccentColor.cgColor)
            context.setLineWidth(1)
            context.fill(rect)
            context.stroke(rect)
            context.restoreGState()
        }
    }
}

func toolType(for annotation: Annotation) -> AnnotationTool {
    switch annotation {
    case is RectangleAnnotation: return .rectangle
    case is EllipseAnnotation: return .ellipse
    case is LineAnnotation: return .line
    case is ArrowAnnotation: return .arrow
    case is TextAnnotation: return .text
    case is SpeechBubbleAnnotation: return .speechBubble
    case is StepLabelAnnotation: return .stepLabel
    case is PixelateFilter: return .pixelate
    case is HighlightFilter: return .highlight
    default: return .select
    }
}
