import AppKit

@MainActor
final class EditorWindowController: NSWindowController, NSWindowDelegate {
    let canvasView = CanvasView()
    private let scrollView = NSScrollView()
    private var toolbar: NSToolbar!
    private let sourceURL: URL?
    private let originalImage: NSImage

    init(image: NSImage, sourceURL: URL?) {
        self.originalImage = image
        self.sourceURL = sourceURL

        let contentRect = NSRect(x: 0, y: 0, width: min(image.size.width + 40, 1200),
                                 height: min(image.size.height + 80, 800))
        let window = NSWindow(contentRect: contentRect,
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered,
                              defer: false)
        window.title = sourceURL?.lastPathComponent ?? "Untitled"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self

        setupScrollView()
        setupCanvas(image: image)
        setupToolbar()
        setupMenuItems()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    // MARK: - Setup

    private func setupScrollView() {
        guard let contentView = window?.contentView else { return }
        scrollView.frame = contentView.bounds
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.1
        scrollView.maxMagnification = 10.0
        scrollView.magnification = 1.0
        contentView.addSubview(scrollView)
    }

    private func setupCanvas(image: NSImage) {
        canvasView.frame = NSRect(origin: .zero, size: image.size)
        canvasView.backgroundImage = image
        canvasView.setupUndoManager()
        scrollView.documentView = canvasView
    }

    private func setupToolbar() {
        toolbar = NSToolbar(identifier: "EditorToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
        window?.toolbar = toolbar
    }

    private func setupMenuItems() {
        // Keyboard shortcuts handled via responder chain
    }

    // MARK: - Actions

    @objc func selectTool(_ sender: NSToolbarItem) {
        guard let tool = AnnotationTool(rawValue: sender.itemIdentifier.rawValue) else { return }
        canvasView.currentTool = tool
    }

    @objc func copyToClipboard(_ sender: Any?) {
        guard let image = canvasView.renderFinalImage() else { return }
        ClipboardExporter.copy(image: image)
    }

    @objc func saveToFile(_ sender: Any?) {
        guard let image = canvasView.renderFinalImage() else { return }
        FileExporter.save(image: image, suggestedName: sourceURL?.deletingPathExtension().lastPathComponent, from: window)
    }

    @objc func toggleShadow(_ sender: Any?) {
        canvasView.currentStyle.shadow = canvasView.currentStyle.shadow.enabled
            ? .none : .default
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.editorDidClose(self)
        }
    }
}

// MARK: - NSToolbarDelegate

extension EditorWindowController: NSToolbarDelegate {
    static let toolIdentifiers: [NSToolbarItem.Identifier] = [
        .init("select"), .init("rectangle"), .init("ellipse"),
        .init("line"), .init("arrow"), .init("text"),
        .init("speechBubble"), .init("stepLabel"),
        .flexibleSpace,
        .init("pixelate"), .init("highlight"), .init("crop"),
        .flexibleSpace,
        .init("shadow"), .init("copyClipboard"), .init("saveFile")
    ]

    static let toolLabels: [String: String] = [
        "select": "Select", "rectangle": "Rectangle", "ellipse": "Ellipse",
        "line": "Line", "arrow": "Arrow", "text": "Text",
        "speechBubble": "Bubble", "stepLabel": "Step",
        "pixelate": "Pixelate", "highlight": "Highlight", "crop": "Crop",
        "shadow": "Shadow", "copyClipboard": "Copy", "saveFile": "Save"
    ]

    static let toolIcons: [String: String] = [
        "select": "arrow.uturn.left.circle", "rectangle": "rectangle",
        "ellipse": "circle", "line": "line.diagonal",
        "arrow": "arrow.right", "text": "textformat",
        "speechBubble": "bubble.left", "stepLabel": "number.circle",
        "pixelate": "squareshape.split.3x3", "highlight": "highlighter",
        "crop": "crop", "shadow": "shadow",
        "copyClipboard": "doc.on.clipboard", "saveFile": "square.and.arrow.down"
    ]

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Self.toolIdentifiers
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Self.toolIdentifiers
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let id = itemIdentifier.rawValue
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = Self.toolLabels[id] ?? id
        item.toolTip = item.label

        if let iconName = Self.toolIcons[id] {
            item.image = NSImage(systemSymbolName: iconName, accessibilityDescription: item.label)
        }

        switch id {
        case "copyClipboard":
            item.target = self
            item.action = #selector(copyToClipboard)
        case "saveFile":
            item.target = self
            item.action = #selector(saveToFile)
        case "shadow":
            item.target = self
            item.action = #selector(toggleShadow)
        default:
            item.target = self
            item.action = #selector(selectTool)
        }

        return item
    }
}
