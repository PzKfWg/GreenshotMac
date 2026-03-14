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
    case freehand
    case obfuscate
    case crop

    var supportsStrokeColor: Bool {
        switch self {
        case .rectangle, .ellipse, .line, .arrow, .freehand, .text, .speechBubble, .stepLabel:
            return true
        default:
            return false
        }
    }

    var supportsFillColor: Bool {
        switch self {
        case .rectangle, .ellipse, .text, .speechBubble, .stepLabel, .highlight:
            return true
        default:
            return false
        }
    }

    var supportsStrokeWidth: Bool {
        switch self {
        case .rectangle, .ellipse, .line, .arrow, .freehand, .text, .speechBubble:
            return true
        default:
            return false
        }
    }

    var supportsShadow: Bool {
        switch self {
        case .rectangle, .ellipse, .line, .arrow, .freehand, .text, .speechBubble, .stepLabel:
            return true
        default:
            return false
        }
    }

    var supportsFontSize: Bool {
        switch self {
        case .text, .speechBubble:
            return true
        default:
            return false
        }
    }

    var supportsFontStyle: Bool {
        switch self {
        case .text, .speechBubble:
            return true
        default:
            return false
        }
    }

    var supportsArrowHeads: Bool {
        self == .arrow
    }

    var supportsPixelSize: Bool {
        self == .pixelate
    }

    var supportsBlurRadius: Bool {
        self == .obfuscate
    }

    var supportsStartNumber: Bool {
        self == .stepLabel
    }

    var supportsDashPattern: Bool {
        switch self {
        case .rectangle, .ellipse, .line, .arrow, .freehand, .text, .speechBubble:
            return true
        default:
            return false
        }
    }

    var supportsCornerRadius: Bool {
        self == .rectangle
    }

    var supportsOpacity: Bool {
        switch self {
        case .rectangle, .ellipse, .line, .arrow, .freehand, .text, .speechBubble, .stepLabel, .highlight:
            return true
        default:
            return false
        }
    }

    var supportsTextAlignment: Bool {
        switch self {
        case .text, .speechBubble:
            return true
        default:
            return false
        }
    }

    var supportsUnderline: Bool {
        switch self {
        case .text, .speechBubble:
            return true
        default:
            return false
        }
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

enum DashPattern: String, CaseIterable, Sendable, Equatable {
    case solid
    case dashed
    case dotted

    var lengths: [CGFloat] {
        switch self {
        case .solid: return []
        case .dashed: return [8, 4]
        case .dotted: return [2, 4]
        }
    }

    func apply(to context: CGContext) {
        let l = lengths
        if l.isEmpty {
            context.setLineDash(phase: 0, lengths: [])
        } else {
            context.setLineDash(phase: 0, lengths: l)
        }
    }
}

enum TextHorizontalAlignment: Sendable, Equatable {
    case left
    case center
    case right
}

enum TextVerticalAlignment: Sendable, Equatable {
    case top
    case center
    case bottom
}

struct AnnotationStyle: Equatable {
    var strokeColor: NSColor = .systemRed
    var fillColor: NSColor = .clear
    var strokeWidth: CGFloat = 2.0
    var fontSize: CGFloat = 14.0
    var fontName: String = "Helvetica"
    var fontBold: Bool = false
    var fontItalic: Bool = false
    var textHorizontalAlignment: TextHorizontalAlignment = .center
    var textVerticalAlignment: TextVerticalAlignment = .center
    var shadow: ShadowStyle = .default
    var dashPattern: DashPattern = .solid
    var opacity: CGFloat = 1.0
    var fontUnderline: Bool = false
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
    case is FreehandAnnotation: return .freehand
    case is PixelateFilter: return .pixelate
    case is HighlightFilter: return .highlight
    case is ObfuscateFilter: return .obfuscate
    default: return .select
    }
}
