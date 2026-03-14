import AppKit

@MainActor
final class EditorWindowController: NSWindowController, NSWindowDelegate {
    let canvasView = CanvasView()
    private let scrollView = NSScrollView()
    private let toolSidebar = ToolSidebarView()
    private var toolbar: NSToolbar!
    private let sourceURL: URL?
    private let originalImage: NSImage

    // Style toolbar controls
    private let strokeColorWell = NSColorWell(style: .minimal)
    private let fillColorWell = NSColorWell(style: .minimal)
    private let widthPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let pixelSizePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let startNumberStepper = NSStepper()
    private let startNumberLabel = NSTextField(labelWithString: "1")
    private let startNumberContainer = NSStackView()

    private var isUpdatingControls = false

    init(image: NSImage, sourceURL: URL?) {
        self.originalImage = image
        self.sourceURL = sourceURL

        let contentRect = NSRect(x: 0, y: 0, width: min(image.size.width + 120, 1200),
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

        setupLayout()
        setupCanvas(image: image)
        setupToolbar()
        setupMenuItems()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    // MARK: - Setup

    private func setupLayout() {
        guard let contentView = window?.contentView else { return }

        toolSidebar.translatesAutoresizingMaskIntoConstraints = false
        toolSidebar.delegate = self
        contentView.addSubview(toolSidebar)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.1
        scrollView.maxMagnification = 10.0
        scrollView.magnification = 1.0
        contentView.addSubview(scrollView)

        let sidebarWidth: CGFloat = 80

        NSLayoutConstraint.activate([
            toolSidebar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            toolSidebar.topAnchor.constraint(equalTo: contentView.topAnchor),
            toolSidebar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            toolSidebar.widthAnchor.constraint(equalToConstant: sidebarWidth),

            scrollView.leadingAnchor.constraint(equalTo: toolSidebar.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    private func setupCanvas(image: NSImage) {
        canvasView.frame = NSRect(origin: .zero, size: image.size)
        canvasView.backgroundImage = image
        canvasView.delegate = self
        canvasView.setupUndoManager()
        scrollView.documentView = canvasView
    }

    private func setupToolbar() {
        setupStyleControls()

        toolbar = NSToolbar(identifier: "EditorToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
        window?.toolbar = toolbar
    }

    private func setupStyleControls() {
        strokeColorWell.color = canvasView.currentStyle.strokeColor
        strokeColorWell.toolTip = "Stroke Color"
        strokeColorWell.target = self
        strokeColorWell.action = #selector(strokeColorChanged(_:))

        fillColorWell.color = canvasView.currentStyle.fillColor
        fillColorWell.toolTip = "Fill Color"
        fillColorWell.target = self
        fillColorWell.action = #selector(fillColorChanged(_:))

        let widths: [CGFloat] = [1, 2, 3, 5, 8, 12]
        for w in widths {
            widthPopup.addItem(withTitle: "\(Int(w)) pt")
            widthPopup.lastItem?.tag = Int(w)
        }
        selectWidthInPopup(canvasView.currentStyle.strokeWidth)
        widthPopup.toolTip = "Stroke Width"
        widthPopup.target = self
        widthPopup.action = #selector(widthChanged(_:))

        let pixelSizes = [3, 5, 7, 9, 12, 15, 20]
        for ps in pixelSizes {
            pixelSizePopup.addItem(withTitle: "\(ps) px")
            pixelSizePopup.lastItem?.tag = ps
        }
        // Default to 5px
        if let item = pixelSizePopup.itemArray.first(where: { $0.tag == 5 }) {
            pixelSizePopup.select(item)
        }
        pixelSizePopup.toolTip = "Pixel Size"
        pixelSizePopup.target = self
        pixelSizePopup.action = #selector(pixelSizeChanged(_:))
        pixelSizePopup.isHidden = true

        // Start number stepper for step labels
        let savedStart = Preferences.shared.stepLabelStartNumber
        startNumberStepper.minValue = 1
        startNumberStepper.maxValue = 999
        startNumberStepper.increment = 1
        startNumberStepper.integerValue = savedStart
        startNumberStepper.valueWraps = false
        startNumberStepper.target = self
        startNumberStepper.action = #selector(startNumberChanged(_:))

        startNumberLabel.stringValue = "\(savedStart)"
        startNumberLabel.alignment = .center
        startNumberLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        startNumberContainer.orientation = .horizontal
        startNumberContainer.spacing = 4
        startNumberContainer.addArrangedSubview(startNumberLabel)
        startNumberContainer.addArrangedSubview(startNumberStepper)
        startNumberContainer.isHidden = true

        StepLabelAnnotation.setCounter(to: savedStart)

        // Enable alpha slider in color panel
        NSColorPanel.shared.showsAlpha = true
    }

    private func selectWidthInPopup(_ width: CGFloat) {
        let tag = Int(width)
        if let index = widthPopup.itemArray.firstIndex(where: { $0.tag == tag }) {
            widthPopup.selectItem(at: index)
        } else {
            // Select closest
            let closest = widthPopup.itemArray.min(by: { abs($0.tag - tag) < abs($1.tag - tag) })
            if let closest { widthPopup.select(closest) }
        }
    }

    private func selectPixelSizeInPopup(_ size: Int) {
        if let item = pixelSizePopup.itemArray.first(where: { $0.tag == size }) {
            pixelSizePopup.select(item)
        } else {
            let closest = pixelSizePopup.itemArray.min(by: { abs($0.tag - size) < abs($1.tag - size) })
            if let closest { pixelSizePopup.select(closest) }
        }
    }

    private func setupMenuItems() {
        // Keyboard shortcuts handled via responder chain
    }

    // MARK: - Style Control Actions

    @objc private func strokeColorChanged(_ sender: NSColorWell) {
        guard !isUpdatingControls else { return }
        canvasView.currentStyle.strokeColor = sender.color
        applyStyleToSelectedAnnotation()
        Preferences.shared.defaultStrokeColor = sender.color
    }

    @objc private func fillColorChanged(_ sender: NSColorWell) {
        guard !isUpdatingControls else { return }
        canvasView.currentStyle.fillColor = sender.color
        applyStyleToSelectedAnnotation()
        Preferences.shared.defaultFillColor = sender.color
    }

    @objc private func widthChanged(_ sender: NSPopUpButton) {
        guard !isUpdatingControls else { return }
        let width = CGFloat(sender.selectedItem?.tag ?? 2)
        canvasView.currentStyle.strokeWidth = width
        applyStyleToSelectedAnnotation()
        Preferences.shared.defaultStrokeWidth = width
    }

    @objc private func startNumberChanged(_ sender: NSStepper) {
        guard !isUpdatingControls else { return }
        let value = sender.integerValue
        startNumberLabel.stringValue = "\(value)"
        StepLabelAnnotation.setCounter(to: value)
        Preferences.shared.stepLabelStartNumber = value
    }

    @objc private func pixelSizeChanged(_ sender: NSPopUpButton) {
        guard !isUpdatingControls else { return }
        let size = sender.selectedItem?.tag ?? 5
        if let pf = canvasView.selectedAnnotation as? PixelateFilter {
            let oldBounds = pf.bounds
            let oldStyle = pf.style
            pf.pixelSize = size
            canvasView.annotationUndoManager.recordModify(pf, oldBounds: oldBounds, oldStyle: oldStyle)
            canvasView.needsDisplay = true
        }
    }

    private func applyStyleToSelectedAnnotation() {
        guard let annotation = canvasView.selectedAnnotation else { return }
        let tool = toolType(for: annotation)
        guard tool.supportsStrokeColor || tool.supportsFillColor || tool.supportsStrokeWidth || tool.supportsShadow else { return }

        let oldBounds = annotation.bounds
        let oldStyle = annotation.style

        if tool.supportsStrokeColor {
            annotation.style.strokeColor = canvasView.currentStyle.strokeColor
        }
        if tool.supportsFillColor {
            annotation.style.fillColor = canvasView.currentStyle.fillColor
        }
        if tool.supportsStrokeWidth {
            annotation.style.strokeWidth = canvasView.currentStyle.strokeWidth
        }
        if tool.supportsShadow {
            annotation.style.shadow = canvasView.currentStyle.shadow
        }

        if annotation.style != oldStyle {
            canvasView.annotationUndoManager.recordModify(annotation, oldBounds: oldBounds, oldStyle: oldStyle)
            canvasView.needsDisplay = true
        }
    }

    // MARK: - Style Bar Visibility

    private func updateStyleControls(for tool: AnnotationTool, style: AnnotationStyle) {
        isUpdatingControls = true
        defer { isUpdatingControls = false }

        strokeColorWell.isHidden = !tool.supportsStrokeColor
        fillColorWell.isHidden = !tool.supportsFillColor
        widthPopup.isHidden = !tool.supportsStrokeWidth
        pixelSizePopup.isHidden = !tool.supportsPixelSize
        startNumberContainer.isHidden = !tool.supportsStartNumber

        if tool.supportsStrokeColor {
            strokeColorWell.color = style.strokeColor
        }
        if tool.supportsFillColor {
            fillColorWell.color = style.fillColor
        }
        if tool.supportsStrokeWidth {
            selectWidthInPopup(style.strokeWidth)
        }
        if tool.supportsPixelSize, let pf = canvasView.selectedAnnotation as? PixelateFilter {
            selectPixelSizeInPopup(pf.pixelSize)
        }
        if tool.supportsStartNumber {
            let current = StepLabelAnnotation.currentCounter
            startNumberStepper.integerValue = current
            startNumberLabel.stringValue = "\(current)"
        }

        // Update toolbar items visibility by revalidating
        toolbar?.validateVisibleItems()
    }

    // MARK: - Other Actions

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
        applyStyleToSelectedAnnotation()
        Preferences.shared.defaultShadowEnabled = canvasView.currentStyle.shadow.enabled
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.editorDidClose(self)
        }
    }
}

// MARK: - ToolSidebarDelegate

extension EditorWindowController: ToolSidebarDelegate {
    func toolSidebar(_ sidebar: ToolSidebarView, didSelectTool tool: AnnotationTool) {
        canvasView.currentTool = tool
    }
}

// MARK: - CanvasViewDelegate

extension EditorWindowController: CanvasViewDelegate {
    func canvasView(_ canvas: CanvasView, didSelectAnnotation annotation: Annotation?) {
        if let annotation {
            let tool = toolType(for: annotation)
            updateStyleControls(for: tool, style: annotation.style)
        } else {
            updateStyleControls(for: canvas.currentTool, style: canvas.currentStyle)
        }
    }

    func canvasView(_ canvas: CanvasView, didChangeCurrentTool tool: AnnotationTool) {
        toolSidebar.selectTool(tool)
        updateStyleControls(for: tool, style: canvas.currentStyle)
    }
}

// MARK: - NSToolbarDelegate

extension EditorWindowController: NSToolbarDelegate {
    private static let strokeColorId = NSToolbarItem.Identifier("strokeColor")
    private static let fillColorId = NSToolbarItem.Identifier("fillColor")
    private static let strokeWidthId = NSToolbarItem.Identifier("strokeWidth")
    private static let pixelSizeId = NSToolbarItem.Identifier("pixelSize")
    private static let startNumberId = NSToolbarItem.Identifier("startNumber")
    private static let shadowId = NSToolbarItem.Identifier("shadow")
    private static let copyId = NSToolbarItem.Identifier("copyClipboard")
    private static let saveId = NSToolbarItem.Identifier("saveFile")

    static let toolbarIdentifiers: [NSToolbarItem.Identifier] = [
        strokeColorId, fillColorId, strokeWidthId, pixelSizeId, startNumberId,
        .flexibleSpace,
        shadowId,
        .flexibleSpace,
        copyId, saveId,
    ]

    static let toolbarLabels: [NSToolbarItem.Identifier: String] = [
        strokeColorId: "Stroke",
        fillColorId: "Fill",
        strokeWidthId: "Width",
        pixelSizeId: "Pixel Size",
        startNumberId: "Start #",
        shadowId: "Shadow",
        copyId: "Copy",
        saveId: "Save",
    ]

    static let toolbarIcons: [NSToolbarItem.Identifier: String] = [
        shadowId: "shadow",
        copyId: "doc.on.clipboard",
        saveId: "square.and.arrow.down",
    ]

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Self.toolbarIdentifiers
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Self.toolbarIdentifiers
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = Self.toolbarLabels[itemIdentifier] ?? ""
        item.toolTip = item.label

        switch itemIdentifier {
        case Self.strokeColorId:
            item.view = strokeColorWell
        case Self.fillColorId:
            item.view = fillColorWell
        case Self.strokeWidthId:
            widthPopup.sizeToFit()
            item.view = widthPopup
        case Self.pixelSizeId:
            pixelSizePopup.sizeToFit()
            item.view = pixelSizePopup
        case Self.startNumberId:
            item.view = startNumberContainer
        case Self.shadowId:
            item.image = NSImage(systemSymbolName: "shadow", accessibilityDescription: "Shadow")
            item.target = self
            item.action = #selector(toggleShadow)
        case Self.copyId:
            item.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Copy")
            item.target = self
            item.action = #selector(copyToClipboard)
        case Self.saveId:
            item.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: "Save")
            item.target = self
            item.action = #selector(saveToFile)
        default:
            break
        }

        return item
    }
}
