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
        context.setAlpha(style.opacity)
        style.shadow.apply(to: context)

        // Draw background fill if set
        if style.fillColor != .clear {
            context.setFillColor(style.fillColor.cgColor)
            context.fill(bounds)
        }

        // Draw border if stroke width > 0
        if style.strokeWidth > 0 {
            context.setStrokeColor(style.strokeColor.cgColor)
            context.setLineWidth(style.strokeWidth)
            style.dashPattern.apply(to: context)
            context.stroke(bounds)
        }

        let font = resolveFont()
        let paragraphStyle = NSMutableParagraphStyle()
        switch style.textHorizontalAlignment {
        case .left:   paragraphStyle.alignment = .left
        case .center: paragraphStyle.alignment = .center
        case .right:  paragraphStyle.alignment = .right
        }

        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: style.strokeColor,
            .paragraphStyle: paragraphStyle
        ]
        if style.fontUnderline {
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
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
            // In non-flipped CoreText coords, text draws from the TOP of the frame downward.
            // To center: reduce frame height so its top edge is at the vertical center.
            let targetHeight = min(localRect.height, (localRect.height + textSize.height) / 2)
            drawRect.size.height = targetHeight
        case .bottom:
            // To bottom-align: set frame height to text height so text sits at the bottom.
            let targetHeight = min(localRect.height, textSize.height)
            drawRect.size.height = targetHeight
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
