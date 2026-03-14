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

    /// Default style for step labels, aligned with Greenshot Windows:
    /// DarkRed fill, white text, no border (lineThickness=0), no shadow
    static var defaultStyle: AnnotationStyle {
        var s = AnnotationStyle()
        s.fillColor = NSColor(red: 0.55, green: 0, blue: 0, alpha: 1) // DarkRed
        s.strokeColor = .white // number color
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
        style.shadow.apply(to: context)

        let fillColor = style.fillColor == .clear ? NSColor.systemRed : style.fillColor
        context.setFillColor(fillColor.cgColor)
        context.fillEllipse(in: bounds)

        context.restoreGState()

        // Draw the number centered in the circle with auto-scaled font
        // Matching Greenshot Windows: font size adapts to circle diameter
        let numStr = "\(stepNumber)" as NSString
        let fontSize = autoScaledFontSize(for: numStr as String)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: fontSize),
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

    // MARK: - Font auto-scaling

    /// Calculates the font size to fit the text inside the circle,
    /// matching Greenshot Windows StepLabelContainer algorithm.
    func autoScaledFontSize(for text: String) -> CGFloat {
        let diameter = min(bounds.width, bounds.height)
        guard diameter > 0 else { return style.fontSize }

        // Start with diameter as initial size, then scale down to fit
        let initialSize = diameter
        let testFont = NSFont.boldSystemFont(ofSize: initialSize)
        let testStr = text as NSString
        let textSize = testStr.size(withAttributes: [.font: testFont])

        guard textSize.width > 0 else { return initialSize }

        // Scale factor: fit text within ~70% of circle diameter
        // (0.7 matches Greenshot Windows optimization factor)
        let scaleFactor = (textSize.height / textSize.width) * 0.7
        return max(8, initialSize * scaleFactor)
    }
}
