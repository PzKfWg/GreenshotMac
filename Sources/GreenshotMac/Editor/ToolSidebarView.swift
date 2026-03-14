import AppKit

@MainActor
protocol ToolSidebarDelegate: AnyObject {
    func toolSidebar(_ sidebar: ToolSidebarView, didSelectTool tool: AnnotationTool)
}

@MainActor
final class ToolSidebarView: NSView {
    weak var delegate: ToolSidebarDelegate?

    private var buttons: [AnnotationTool: NSButton] = [:]

    private static let toolRows: [[(tool: AnnotationTool, icon: String, label: String)]] = [
        [(.select, "arrow.uturn.left.circle", "Select"), (.rectangle, "rectangle", "Rectangle")],
        [(.ellipse, "circle", "Ellipse"), (.line, "line.diagonal", "Line")],
        [(.arrow, "arrow.right", "Arrow"), (.text, "textformat", "Text")],
        [(.speechBubble, "bubble.left", "Bubble"), (.stepLabel, "number.circle", "Step")],
        // separator
        [(.pixelate, "squareshape.split.3x3", "Pixelate"), (.highlight, "highlighter", "Highlight")],
        [(.crop, "crop", "Crop")],
    ]

    private static let separatorAfterRow = 3

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
        ])

        for (rowIndex, row) in Self.toolRows.enumerated() {
            if rowIndex == Self.separatorAfterRow + 1 {
                let separator = NSBox()
                separator.boxType = .separator
                separator.translatesAutoresizingMaskIntoConstraints = false
                stack.addArrangedSubview(separator)
                separator.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -8).isActive = true
            }

            let rowStack = NSStackView()
            rowStack.orientation = .horizontal
            rowStack.spacing = 2
            rowStack.distribution = .fillEqually

            for entry in row {
                let button = makeToolButton(tool: entry.tool, icon: entry.icon, label: entry.label)
                buttons[entry.tool] = button
                rowStack.addArrangedSubview(button)
            }

            // If odd number of tools in row, add spacer for alignment
            if row.count == 1 {
                let spacer = NSView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                rowStack.addArrangedSubview(spacer)
            }

            stack.addArrangedSubview(rowStack)
            rowStack.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        // Select the select tool by default
        buttons[.select]?.state = .on
    }

    private func makeToolButton(tool: AnnotationTool, icon: String, label: String) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .toolbar
        button.setButtonType(.toggle)
        button.image = NSImage(systemSymbolName: icon, accessibilityDescription: label)
        button.toolTip = label
        button.imagePosition = .imageOnly
        button.tag = AnnotationTool.allCases.firstIndex(of: tool) ?? 0
        button.target = self
        button.action = #selector(toolButtonClicked(_:))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 32).isActive = true
        button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return button
    }

    @objc private func toolButtonClicked(_ sender: NSButton) {
        let tool = AnnotationTool.allCases[sender.tag]
        selectTool(tool)
        delegate?.toolSidebar(self, didSelectTool: tool)
    }

    func selectTool(_ tool: AnnotationTool) {
        for (t, button) in buttons {
            button.state = (t == tool) ? .on : .off
        }
    }
}
