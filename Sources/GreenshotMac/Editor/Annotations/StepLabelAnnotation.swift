import AppKit

@MainActor
final class StepLabelAnnotation: Annotation {
    let id = UUID()
    var bounds: CGRect
    var style: AnnotationStyle
    var isSelected: Bool = false
    var stepNumber: Int

    private static var nextStepNumber = 1

    static func resetCounter() {
        nextStepNumber = 1
    }

    init(center: CGPoint, style: AnnotationStyle = AnnotationStyle()) {
        let size: CGFloat = 30
        self.bounds = CGRect(
            x: center.x - size / 2,
            y: center.y - size / 2,
            width: size,
            height: size
        )
        self.style = style
        self.stepNumber = Self.nextStepNumber
        Self.nextStepNumber += 1
    }

    private init(bounds: CGRect, style: AnnotationStyle, stepNumber: Int) {
        self.bounds = bounds
        self.style = style
        self.stepNumber = stepNumber
    }

    func draw(in context: CGContext) {
        context.saveGState()
        style.shadow.apply(to: context)

        let fillColor = style.fillColor == .clear ? NSColor.systemRed : style.fillColor
        context.setFillColor(fillColor.cgColor)
        context.fillEllipse(in: bounds)

        context.restoreGState()

        // Draw the number centered in the circle
        let numStr = "\(stepNumber)" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: style.fontSize),
            .foregroundColor: NSColor.white
        ]
        let size = numStr.size(withAttributes: attrs)
        let textOrigin = CGPoint(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2
        )
        numStr.draw(at: textOrigin, withAttributes: attrs)

        drawSelectionHandles(in: context)
    }

    func hitTest(point: CGPoint) -> Bool {
        let centerX = bounds.midX
        let centerY = bounds.midY
        let radius = bounds.width / 2
        let tolerance: CGFloat = 4
        let dx = point.x - centerX
        let dy = point.y - centerY
        return (dx * dx + dy * dy) <= (radius + tolerance) * (radius + tolerance)
    }

    func copy() -> Annotation {
        let c = StepLabelAnnotation(bounds: bounds, style: style, stepNumber: stepNumber)
        return c
    }
}
