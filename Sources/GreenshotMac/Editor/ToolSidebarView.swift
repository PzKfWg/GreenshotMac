import AppKit

@MainActor
protocol ToolSidebarDelegate: AnyObject {
    func toolSidebar(_ sidebar: ToolSidebarView, didSelectTool tool: AnnotationTool)
}

@MainActor
final class ToolSidebarView: NSView {
    weak var delegate: ToolSidebarDelegate?

    var buttons: [AnnotationTool: NSButton] = [:]

    private static let toolRows: [[(tool: AnnotationTool, icon: String, label: String)]] = [
        [(.select, "arrow.uturn.left.circle", "Sélection (1)"), (.rectangle, "rectangle", "Rectangle (2)")],
        [(.ellipse, "circle", "Ellipse (3)"), (.line, "line.diagonal", "Ligne (4)")],
        [(.arrow, "arrow.right", "Flèche (5)"), (.text, "textformat", "Texte (6)")],
        [(.speechBubble, "bubble.left", "Bulle (7)"), (.stepLabel, "number.circle", "Étape (8)")],
        // séparateur
        [(.freehand, "pencil.tip", "Crayon"), (.pixelate, "squareshape.split.3x3", "Pixeliser (9)")],
        [(.highlight, "highlighter", "Surligner (0)"), (.obfuscate, "eye.slash", "Flouter")],
        [(.crop, "crop", "Recadrer")],
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
        selectTool(.select)
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
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 32).isActive = true
        button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return button
    }

    @objc func toolButtonClicked(_ sender: NSButton) {
        let tool = AnnotationTool.allCases[sender.tag]
        selectTool(tool)
        delegate?.toolSidebar(self, didSelectTool: tool)
    }

    func selectTool(_ tool: AnnotationTool) {
        for (t, button) in buttons {
            let selected = (t == tool)
            button.state = selected ? .on : .off
            button.layer?.backgroundColor = selected
                ? NSColor.controlAccentColor.withAlphaComponent(0.25).cgColor
                : nil
        }
    }
}
