import AppKit

@MainActor
final class SpeechBubbleAnnotation: Annotation {
    let id = UUID()
    var bounds: CGRect
    var style: AnnotationStyle
    var isSelected: Bool = false
    var text: String = "Text"
    var tailPoint: CGPoint

    private let cornerRadius: CGFloat = 8

    init(bounds: CGRect, style: AnnotationStyle = AnnotationStyle(), text: String = "Text", tailPoint: CGPoint? = nil) {
        self.bounds = bounds
        self.style = style
        self.text = text
        self.tailPoint = tailPoint ?? CGPoint(x: bounds.midX, y: bounds.minY - 30)
    }

    func draw(in context: CGContext) {
        context.saveGState()
        style.shadow.apply(to: context)

        let path = buildPath()

        // Fill
        if style.fillColor != .clear {
            context.addPath(path)
            context.setFillColor(style.fillColor.cgColor)
            context.fillPath()
        }

        // Stroke
        context.addPath(path)
        context.setStrokeColor(style.strokeColor.cgColor)
        context.setLineWidth(style.strokeWidth)
        context.strokePath()

        context.restoreGState()

        // Draw text inside the body
        context.saveGState()
        let textInset = bounds.insetBy(dx: 6, dy: 4)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: style.fontName, size: style.fontSize)
                ?? NSFont.systemFont(ofSize: style.fontSize),
            .foregroundColor: style.strokeColor
        ]
        let attrString = NSAttributedString(string: text, attributes: attrs)
        let framesetter = CTFramesetterCreateWithAttributedString(attrString)
        let textPath = CGPath(rect: textInset, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), textPath, nil)
        CTFrameDraw(frame, context)
        context.restoreGState()

        drawSelectionHandles(in: context)
    }

    func hitTest(point: CGPoint) -> Bool {
        let bodyArea = bounds.insetBy(dx: -4, dy: -4)
        if bodyArea.contains(point) {
            return true
        }
        return isNearTail(point: point)
    }

    func copy() -> Annotation {
        let c = SpeechBubbleAnnotation(bounds: bounds, style: style, text: text, tailPoint: tailPoint)
        return c
    }

    // MARK: - Private

    private func buildPath() -> CGPath {
        let path = CGMutablePath()

        // Rounded rectangle body
        path.addRoundedRect(in: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius)

        // Tail triangle from bottom-center of body to tailPoint
        let tailWidth: CGFloat = min(20, bounds.width * 0.3)
        let bottomCenter = CGPoint(x: bounds.midX, y: bounds.minY)
        let tailLeft = CGPoint(x: bottomCenter.x - tailWidth / 2, y: bottomCenter.y)
        let tailRight = CGPoint(x: bottomCenter.x + tailWidth / 2, y: bottomCenter.y)

        path.move(to: tailLeft)
        path.addLine(to: tailPoint)
        path.addLine(to: tailRight)
        path.closeSubpath()

        return path
    }

    private func isNearTail(point: CGPoint) -> Bool {
        let tailWidth: CGFloat = min(20, bounds.width * 0.3)
        let bottomCenter = CGPoint(x: bounds.midX, y: bounds.minY)
        let tailLeft = CGPoint(x: bottomCenter.x - tailWidth / 2, y: bottomCenter.y)
        let tailRight = CGPoint(x: bottomCenter.x + tailWidth / 2, y: bottomCenter.y)

        // Check if point is inside the tail triangle using barycentric coordinates
        return pointInTriangle(point, v1: tailLeft, v2: tailPoint, v3: tailRight)
    }

    private func pointInTriangle(_ p: CGPoint, v1: CGPoint, v2: CGPoint, v3: CGPoint) -> Bool {
        let d1 = sign(p, v1, v2)
        let d2 = sign(p, v2, v3)
        let d3 = sign(p, v3, v1)

        let hasNeg = (d1 < 0) || (d2 < 0) || (d3 < 0)
        let hasPos = (d1 > 0) || (d2 > 0) || (d3 > 0)

        return !(hasNeg && hasPos)
    }

    private func sign(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint) -> CGFloat {
        return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)
    }
}
