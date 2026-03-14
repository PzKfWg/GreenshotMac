import AppKit

@MainActor
final class SpeechBubbleAnnotation: Annotation {
    let id = UUID()
    var bounds: CGRect
    var style: AnnotationStyle
    var isSelected: Bool = false
    var text: String = "Texte"
    var tailPoint: CGPoint

    /// Adaptive corner radius matching Greenshot Windows:
    /// min(30, smallerSide / 2 - lineThickness)
    var cornerRadius: CGFloat {
        let smallerSide = min(abs(bounds.width), abs(bounds.height))
        return max(0, min(30, smallerSide / 2 - style.strokeWidth))
    }

    /// Tail width matching Greenshot Windows formula:
    /// (|width| + |height|) / 20, capped to half of each dimension
    var tailWidth: CGFloat {
        var w = (abs(bounds.width) + abs(bounds.height)) / 20
        w = min(abs(bounds.width) / 2, w)
        w = min(abs(bounds.height) / 2, w)
        return max(4, w) // minimum 4px to remain visible
    }

    /// Default style for speech bubble, aligned with Greenshot Windows defaults:
    /// Blue stroke, white fill, bold, 20pt font, no shadow
    static var defaultStyle: AnnotationStyle {
        var s = AnnotationStyle()
        s.strokeColor = .systemBlue
        s.fillColor = .white
        s.fontBold = true
        s.fontSize = 20.0
        s.shadow = .none
        return s
    }

    init(bounds: CGRect, style: AnnotationStyle? = nil, text: String = "Texte", tailPoint: CGPoint? = nil) {
        self.bounds = bounds
        self.style = style ?? SpeechBubbleAnnotation.defaultStyle
        self.text = text
        // In flipped coords (isFlipped=true), maxY is the bottom edge
        self.tailPoint = tailPoint ?? CGPoint(x: bounds.midX, y: bounds.maxY + 30)
    }

    func draw(in context: CGContext) {
        context.saveGState()
        context.setAlpha(style.opacity)
        style.shadow.apply(to: context)

        let bubblePath = buildBubblePath()
        let tailPath = buildTailPath()

        // Fill bubble body
        if style.fillColor != .clear {
            context.addPath(bubblePath)
            context.setFillColor(style.fillColor.cgColor)
            context.fillPath()
        }

        // Fill tail
        if style.fillColor != .clear {
            context.addPath(tailPath)
            context.setFillColor(style.fillColor.cgColor)
            context.fillPath()
        }

        // Stroke bubble
        context.addPath(bubblePath)
        context.setStrokeColor(style.strokeColor.cgColor)
        context.setLineWidth(style.strokeWidth)
        style.dashPattern.apply(to: context)
        context.strokePath()

        // Stroke tail (only the two outer edges, not the base that overlaps with bubble)
        context.addPath(tailPath)
        context.setStrokeColor(style.strokeColor.cgColor)
        context.setLineWidth(style.strokeWidth)
        style.dashPattern.apply(to: context)
        context.strokePath()

        context.restoreGState()

        // Draw text inside the body
        drawText(in: context)

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
        SpeechBubbleAnnotation(bounds: bounds, style: style, text: text, tailPoint: tailPoint)
    }

    // MARK: - Text rendering (uses bold/italic/alignment from iteration 2)

    private func drawText(in context: CGContext) {
        context.saveGState()

        let textInset = bounds.insetBy(dx: 6, dy: 4)
        guard textInset.width > 0 && textInset.height > 0 else {
            context.restoreGState()
            return
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
        context.translateBy(x: textInset.origin.x, y: textInset.origin.y + textInset.height)
        context.scaleBy(x: 1.0, y: -1.0)

        let localRect = CGRect(origin: .zero, size: textInset.size)

        // Vertical alignment
        let textSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRangeMake(0, 0),
            nil,
            CGSize(width: textInset.width, height: CGFloat.greatestFiniteMagnitude),
            nil
        )

        var drawRect = localRect
        switch style.textVerticalAlignment {
        case .top:
            break
        case .center:
            let yOffset = max(0, (localRect.height - textSize.height) / 2)
            drawRect.origin.y = yOffset
            drawRect.size.height = localRect.height - yOffset
        case .bottom:
            let yOffset = max(0, localRect.height - textSize.height)
            drawRect.origin.y = yOffset
            drawRect.size.height = localRect.height - yOffset
        }

        let textPath = CGPath(rect: drawRect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), textPath, nil)
        CTFrameDraw(frame, context)
        context.restoreGState()
    }

    /// Resolves the font with bold/italic traits, same as TextAnnotation
    private func resolveFont() -> NSFont {
        var traits: NSFontTraitMask = []
        if style.fontBold { traits.insert(.boldFontMask) }
        if style.fontItalic { traits.insert(.italicFontMask) }

        if let baseFont = NSFont(name: style.fontName, size: style.fontSize) {
            if !traits.isEmpty {
                if let converted = NSFontManager.shared.convert(baseFont, toHaveTrait: traits) as NSFont? {
                    return converted
                }
            }
            return baseFont
        }

        let systemFont = NSFont.systemFont(ofSize: style.fontSize)
        if !traits.isEmpty {
            if let converted = NSFontManager.shared.convert(systemFont, toHaveTrait: traits) as NSFont? {
                return converted
            }
        }
        return systemFont
    }

    // MARK: - Path construction

    private func buildBubblePath() -> CGPath {
        let cr = cornerRadius
        if cr <= 0 {
            return CGPath(rect: bounds, transform: nil)
        }
        return CGPath(roundedRect: bounds, cornerWidth: cr, cornerHeight: cr, transform: nil)
    }

    /// Determines the nearest edge anchor points for the tail base.
    /// Picks the edge (top/bottom/left/right) nearest to the tail tip.
    private func tailBasePoints() -> (CGPoint, CGPoint) {
        let tw = tailWidth
        let tp = tailPoint

        // Determine which edge the tail is closest to
        let distTop = abs(tp.y - bounds.minY)
        let distBottom = abs(tp.y - bounds.maxY)
        let distLeft = abs(tp.x - bounds.minX)
        let distRight = abs(tp.x - bounds.maxX)

        let minDist = min(distTop, distBottom, distLeft, distRight)

        if minDist == distBottom {
            let center = CGPoint(x: bounds.midX, y: bounds.maxY)
            return (CGPoint(x: center.x - tw / 2, y: center.y),
                    CGPoint(x: center.x + tw / 2, y: center.y))
        } else if minDist == distTop {
            let center = CGPoint(x: bounds.midX, y: bounds.minY)
            return (CGPoint(x: center.x - tw / 2, y: center.y),
                    CGPoint(x: center.x + tw / 2, y: center.y))
        } else if minDist == distLeft {
            let center = CGPoint(x: bounds.minX, y: bounds.midY)
            return (CGPoint(x: center.x, y: center.y - tw / 2),
                    CGPoint(x: center.x, y: center.y + tw / 2))
        } else {
            let center = CGPoint(x: bounds.maxX, y: bounds.midY)
            return (CGPoint(x: center.x, y: center.y - tw / 2),
                    CGPoint(x: center.x, y: center.y + tw / 2))
        }
    }

    private func buildTailPath() -> CGPath {
        let path = CGMutablePath()
        let (tailLeft, tailRight) = tailBasePoints()

        path.move(to: tailLeft)
        path.addLine(to: tailPoint)
        path.addLine(to: tailRight)
        path.closeSubpath()

        return path
    }

    private func isNearTail(point: CGPoint) -> Bool {
        let (tailLeft, tailRight) = tailBasePoints()

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
