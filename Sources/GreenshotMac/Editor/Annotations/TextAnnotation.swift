import AppKit

@MainActor
final class TextAnnotation: Annotation {
    let id = UUID()
    var bounds: CGRect
    var style: AnnotationStyle
    var isSelected: Bool = false
    var text: String = "Text"

    init(bounds: CGRect, style: AnnotationStyle = AnnotationStyle(), text: String = "Text") {
        self.bounds = bounds
        self.style = style
        self.text = text
    }

    func draw(in context: CGContext) {
        context.saveGState()
        style.shadow.apply(to: context)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: style.fontName, size: style.fontSize)
                ?? NSFont.systemFont(ofSize: style.fontSize),
            .foregroundColor: style.strokeColor
        ]
        let attrString = NSAttributedString(string: text, attributes: attrs)
        let framesetter = CTFramesetterCreateWithAttributedString(attrString)
        let path = CGPath(rect: bounds, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
        CTFrameDraw(frame, context)

        context.restoreGState()

        drawSelectionHandles(in: context)
    }

    func copy() -> Annotation {
        let c = TextAnnotation(bounds: bounds, style: style, text: text)
        return c
    }
}
