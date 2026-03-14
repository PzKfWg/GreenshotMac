import AppKit

@MainActor
final class TextAnnotation: Annotation {
    let id = UUID()
    var bounds: CGRect
    var style: AnnotationStyle
    var isSelected: Bool = false
    var text: String = "Texte"

    init(bounds: CGRect, style: AnnotationStyle = AnnotationStyle(), text: String = "Texte") {
        self.bounds = bounds
        self.style = style
        self.text = text
    }

    func draw(in context: CGContext) {
        context.saveGState()
        style.shadow.apply(to: context)

        let font = resolveFont()
        let paragraphStyle = NSMutableParagraphStyle()
        switch style.textHorizontalAlignment {
        case .left:   paragraphStyle.alignment = .left
        case .center: paragraphStyle.alignment = .center
        case .right:  paragraphStyle.alignment = .right
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: style.strokeColor,
            .paragraphStyle: paragraphStyle
        ]
        let attrString = NSAttributedString(string: text, attributes: attrs)
        let framesetter = CTFramesetterCreateWithAttributedString(attrString)

        // CoreText expects bottom-up Y axis; flip for our isFlipped view
        context.translateBy(x: bounds.origin.x, y: bounds.origin.y + bounds.height)
        context.scaleBy(x: 1.0, y: -1.0)

        let localRect = CGRect(origin: .zero, size: bounds.size)

        // Vertical alignment: calculate text height and offset
        let textSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRangeMake(0, 0),
            nil,
            CGSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude),
            nil
        )

        var drawRect = localRect
        switch style.textVerticalAlignment {
        case .top:
            break // default CoreText behavior (top-aligned in flipped coords)
        case .center:
            let yOffset = max(0, (localRect.height - textSize.height) / 2)
            drawRect.origin.y = yOffset
            drawRect.size.height = localRect.height - yOffset
        case .bottom:
            let yOffset = max(0, localRect.height - textSize.height)
            drawRect.origin.y = yOffset
            drawRect.size.height = localRect.height - yOffset
        }

        let path = CGPath(rect: drawRect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
        CTFrameDraw(frame, context)

        context.restoreGState()

        drawSelectionHandles(in: context)
    }

    func copy() -> Annotation {
        TextAnnotation(bounds: bounds, style: style, text: text)
    }

    // MARK: - Font resolution

    /// Resolves the font with bold/italic traits applied, matching Greenshot Windows behavior.
    func resolveFont() -> NSFont {
        let baseFontSize = style.fontSize
        let baseFontName = style.fontName

        var traits: NSFontTraitMask = []
        if style.fontBold { traits.insert(.boldFontMask) }
        if style.fontItalic { traits.insert(.italicFontMask) }

        // Try to get the font with requested traits
        if let baseFont = NSFont(name: baseFontName, size: baseFontSize) {
            if !traits.isEmpty {
                if let converted = NSFontManager.shared.convert(baseFont, toHaveTrait: traits) as NSFont? {
                    return converted
                }
            }
            return baseFont
        }

        // Fallback to system font with traits
        let systemFont = NSFont.systemFont(ofSize: baseFontSize)
        if !traits.isEmpty {
            if let converted = NSFontManager.shared.convert(systemFont, toHaveTrait: traits) as NSFont? {
                return converted
            }
        }
        return systemFont
    }
}
