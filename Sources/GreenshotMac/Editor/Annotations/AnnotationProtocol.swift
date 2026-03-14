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
