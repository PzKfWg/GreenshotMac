import AppKit

/// A custom view that lays out its subviews in a horizontal flow,
/// wrapping to the next row when the available width is exceeded.
final class FlowLayoutView: NSView {
    var horizontalSpacing: CGFloat = 12 { didSet { needsLayout = true } }
    var verticalSpacing: CGFloat = 4 { didSet { needsLayout = true } }
    var edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8) { didSet { needsLayout = true } }

    override var isFlipped: Bool { true }

    private var computedHeight: CGFloat = 0

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: computedHeight)
    }

    override func layout() {
        super.layout()

        let availableWidth = bounds.width - edgeInsets.left - edgeInsets.right
        guard availableWidth > 0 else { return }

        let visibleSubviews = subviews.filter { !$0.isHidden }

        guard !visibleSubviews.isEmpty else {
            if computedHeight != 0 {
                computedHeight = 0
                invalidateIntrinsicContentSize()
            }
            return
        }

        var x = edgeInsets.left
        var y = edgeInsets.top
        var rowHeight: CGFloat = 0

        for view in visibleSubviews {
            let size = view.fittingSize

            // Wrap to next row if this view doesn't fit (unless it's the first on the row)
            if x > edgeInsets.left && x + size.width > bounds.width - edgeInsets.right {
                y += rowHeight + verticalSpacing
                x = edgeInsets.left
                rowHeight = 0
            }

            view.frame = NSRect(x: x, y: y, width: size.width, height: size.height)
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }

        let newHeight = y + rowHeight + edgeInsets.bottom
        if abs(newHeight - computedHeight) > 0.5 {
            computedHeight = newHeight
            invalidateIntrinsicContentSize()
        }
    }
}
