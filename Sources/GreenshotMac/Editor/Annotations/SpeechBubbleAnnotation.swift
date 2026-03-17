import AppKit

@MainActor
final class SpeechBubbleAnnotation: Annotation {
    let id = UUID()
    var bounds: CGRect
    var style: AnnotationStyle
    var isSelected: Bool = false
    var isEditing: Bool = false
    var text: String = "Texte"
    var tailPoint: CGPoint

    var cornerRadius: CGFloat

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

    init(bounds: CGRect, style: AnnotationStyle? = nil, text: String = "Texte", tailPoint: CGPoint? = nil, cornerRadius: CGFloat = 20) {
        self.bounds = bounds
        self.style = style ?? SpeechBubbleAnnotation.defaultStyle
        self.text = text
        self.cornerRadius = cornerRadius
        // In flipped coords (isFlipped=true), maxY is the bottom edge
        self.tailPoint = tailPoint ?? CGPoint(x: bounds.midX, y: bounds.maxY + 30)
    }

    func draw(in context: CGContext) {
        context.saveGState()
        context.setAlpha(style.opacity)
        style.shadow.apply(to: context)

        let bubblePath = buildBubblePath()
        let tailFillPath = buildTailFillPath()
        let tailStrokePath = buildTailStrokePath()

        // Use a transparency layer so the combined fill/stroke casts a single
        // shadow instead of the tail triangle generating its own shadow inside the bubble.
        context.beginTransparencyLayer(auxiliaryInfo: nil)

        // Fill bubble + tail as a combined shape
        if style.fillColor != .clear {
            context.setFillColor(style.fillColor.cgColor)
            context.addPath(bubblePath)
            context.fillPath()
            context.addPath(tailFillPath)
            context.fillPath()
        }

        // Stroke tail, clipping out the bubble interior so lines
        // are only visible outside the bubble (matches original Greenshot)
        context.saveGState()
        let clipRect1 = bounds.standardized.insetBy(dx: -500, dy: -500)
        let tailClipPath = CGMutablePath()
        tailClipPath.addRect(clipRect1)
        tailClipPath.addPath(bubblePath)
        context.addPath(tailClipPath)
        context.clip(using: .evenOdd)

        context.addPath(tailStrokePath)
        context.setStrokeColor(style.strokeColor.cgColor)
        context.setLineWidth(style.strokeWidth)
        style.dashPattern.apply(to: context)
        context.strokePath()
        context.restoreGState()

        // Stroke bubble, clipping out the tail interior so no stroke
        // appears at the junction where the tail exits
        context.saveGState()
        let clipRect2 = bounds.standardized.insetBy(dx: -500, dy: -500)
        let bubbleClipPath = CGMutablePath()
        bubbleClipPath.addRect(clipRect2)
        bubbleClipPath.addPath(tailFillPath)
        context.addPath(bubbleClipPath)
        context.clip(using: .evenOdd)

        context.addPath(bubblePath)
        context.setStrokeColor(style.strokeColor.cgColor)
        context.setLineWidth(style.strokeWidth)
        style.dashPattern.apply(to: context)
        context.strokePath()
        context.restoreGState()

        context.endTransparencyLayer()

        context.restoreGState()

        // Draw text inside the body
        drawText(in: context)

        drawSelectionHandles(in: context)

        if isSelected {
            context.saveGState()
            let handleSize: CGFloat = 8
            let handleRect = CGRect(x: tailPoint.x - handleSize / 2,
                                    y: tailPoint.y - handleSize / 2,
                                    width: handleSize, height: handleSize)
            context.setFillColor(NSColor.controlAccentColor.cgColor)
            context.fillEllipse(in: handleRect)
            context.setStrokeColor(NSColor.white.cgColor)
            context.setLineWidth(1)
            context.strokeEllipse(in: handleRect)
            context.restoreGState()
        }
    }

    func hitTest(point: CGPoint) -> Bool {
        let bodyArea = bounds.insetBy(dx: -4, dy: -4)
        if bodyArea.contains(point) {
            return true
        }
        return isNearTail(point: point)
    }

    func copy() -> Annotation {
        SpeechBubbleAnnotation(bounds: bounds, style: style, text: text, tailPoint: tailPoint, cornerRadius: cornerRadius)
    }

    // MARK: - Text rendering (uses bold/italic/alignment from iteration 2)

    private func drawText(in context: CGContext) {
        guard !isEditing else { return }
        context.saveGState()

        let textInset = bounds.standardized.insetBy(dx: 6, dy: 4)
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
        let flipTransform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1,
                                               tx: textInset.origin.x,
                                               ty: textInset.origin.y + textInset.height)
        context.concatenate(flipTransform)

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
            let targetHeight = min(localRect.height, (localRect.height + textSize.height) / 2)
            drawRect.size.height = targetHeight
        case .bottom:
            let targetHeight = min(localRect.height, textSize.height)
            drawRect.size.height = targetHeight
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
        let rect = bounds.standardized
        let effectiveRadius = min(cornerRadius, min(rect.width, rect.height) / 2)
        if effectiveRadius <= 0 {
            return CGPath(rect: rect, transform: nil)
        }
        return CGPath(roundedRect: rect, cornerWidth: effectiveRadius, cornerHeight: effectiveRadius, transform: nil)
    }

    /// Computes tail base points at the bubble center, perpendicular to the
    /// center→tailPoint direction. Matches the original Greenshot Windows
    /// approach: the triangle rotates smoothly as the tail tip moves.
    private func tailBasePoints() -> (CGPoint, CGPoint) {
        let tw = tailWidth
        let rect = bounds.standardized
        let center = CGPoint(x: rect.midX, y: rect.midY)

        let dx = tailPoint.x - center.x
        let dy = tailPoint.y - center.y
        let angle = atan2(dy, dx)

        // Perpendicular direction to center→tailPoint
        let perpX = -sin(angle)
        let perpY =  cos(angle)

        let baseLeft = CGPoint(
            x: center.x + perpX * (tw / 2),
            y: center.y + perpY * (tw / 2)
        )
        let baseRight = CGPoint(
            x: center.x - perpX * (tw / 2),
            y: center.y - perpY * (tw / 2)
        )

        return (baseLeft, baseRight)
    }

    /// Closed tail triangle for filling (base + two outer edges).
    private func buildTailFillPath() -> CGPath {
        let path = CGMutablePath()
        let (tailLeft, tailRight) = tailBasePoints()
        path.move(to: tailLeft)
        path.addLine(to: tailPoint)
        path.addLine(to: tailRight)
        path.closeSubpath()
        return path
    }

    /// Open tail path for stroking — only the two outer edges, no base line.
    private func buildTailStrokePath() -> CGPath {
        let path = CGMutablePath()
        let (tailLeft, tailRight) = tailBasePoints()
        path.move(to: tailLeft)
        path.addLine(to: tailPoint)
        path.addLine(to: tailRight)
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
