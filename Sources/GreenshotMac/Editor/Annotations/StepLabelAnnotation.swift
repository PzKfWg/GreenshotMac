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

    static func setCounter(to value: Int) {
        nextStepNumber = max(1, value)
    }

    static var currentCounter: Int {
        nextStepNumber
    }

    /// Default style for step labels:
    /// strokeColor = circle background (DarkRed), fillColor = number text color (white), no shadow
    static var defaultStyle: AnnotationStyle {
        var s = AnnotationStyle()
        s.strokeColor = NSColor(red: 0.55, green: 0, blue: 0, alpha: 1) // DarkRed background
        s.fillColor = .white // number text color
        s.shadow = .none
        return s
    }

    init(center: CGPoint, style: AnnotationStyle? = nil) {
        let size: CGFloat = 30
        self.bounds = CGRect(
            x: center.x - size / 2,
            y: center.y - size / 2,
            width: size,
            height: size
        )
        self.style = style ?? StepLabelAnnotation.defaultStyle
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
        context.setAlpha(style.opacity)
        style.shadow.apply(to: context)

        // strokeColor controls the circle background
        let bgColor = style.strokeColor == .clear ? NSColor.systemRed : style.strokeColor
        context.setFillColor(bgColor.cgColor)
        context.fillEllipse(in: bounds)

        context.restoreGState()

        // Draw the number centered in the circle with auto-scaled font
        // fillColor controls the number text color
        let numStr = "\(stepNumber)" as NSString
        let fontSize = autoScaledFontSize(for: numStr as String)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: style.fillColor
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

    // MARK: - Font auto-scaling

    /// Calculates the font size so the text always fits inside the circle.
    /// Uses the inscribed square (~70% of diameter) as the max text extent.
    func autoScaledFontSize(for text: String) -> CGFloat {
        let diameter = min(bounds.width, bounds.height)
        guard diameter > 0 else { return style.fontSize }

        let maxExtent = diameter * 0.70 // inscribed square side ≈ d/√2 ≈ 0.707
        let testSize: CGFloat = 100 // reference size for measuring
        let testFont = NSFont.boldSystemFont(ofSize: testSize)
        let testStr = text as NSString
        let textSize = testStr.size(withAttributes: [.font: testFont])

        guard textSize.width > 0, textSize.height > 0 else { return testSize }

        // Scale so both width and height fit within maxExtent
        let scaleW = maxExtent / textSize.width
        let scaleH = maxExtent / textSize.height
        let fontSize = testSize * min(scaleW, scaleH)
        return max(8, fontSize)
    }
}
