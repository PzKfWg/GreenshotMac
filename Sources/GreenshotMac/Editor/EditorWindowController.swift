import AppKit

@MainActor
final class EditorWindowController: NSWindowController, NSWindowDelegate {
    let canvasView = CanvasView()
    private let scrollView = NSScrollView()
    private let toolSidebar = ToolSidebarView()
    private let statusBar = NSTextField(labelWithString: "")
    private var toolbar: NSToolbar!
    private let sourceURL: URL?
    private let originalImage: NSImage

    // Style toolbar controls
    private let strokeColorWell = NSColorWell(style: .minimal)
    private let fillColorWell = NSColorWell(style: .minimal)
    private let widthPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let fontSizePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let boldButton = NSButton()
    private let italicButton = NSButton()
    private let fontStyleContainer = NSStackView()
    private let arrowHeadPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let pixelSizePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let blurRadiusPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let dashPatternPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let cornerRadiusPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let opacitySlider = NSSlider(value: 1.0, minValue: 0.1, maxValue: 1.0, target: nil, action: nil)
    private let fontNamePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let underlineButton = NSButton()
    private let textAlignPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let startNumberStepper = NSStepper()
    private let startNumberLabel = NSTextField(labelWithString: "1")
    private let startNumberContainer = NSStackView()

    private let styleBar = NSStackView()
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
        window.title = sourceURL?.lastPathComponent ?? "Sans titre"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 400, height: 300)
        window.setFrameAutosaveName("EditorWindow")

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

        // Style bar will be populated in setupStyleBar(), add to layout now
        contentView.addSubview(styleBar)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.1
        scrollView.maxMagnification = 10.0
        scrollView.magnification = 1.0
        contentView.addSubview(scrollView)

        // Status bar (Loop 73)
        statusBar.translatesAutoresizingMaskIntoConstraints = false
        statusBar.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        statusBar.textColor = .secondaryLabelColor
        statusBar.alignment = .left
        statusBar.stringValue = ""
        contentView.addSubview(statusBar)

        let sidebarWidth: CGFloat = 80
        let statusBarHeight: CGFloat = 18

        NSLayoutConstraint.activate([
            toolSidebar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            toolSidebar.topAnchor.constraint(equalTo: contentView.topAnchor),
            toolSidebar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            toolSidebar.widthAnchor.constraint(equalToConstant: sidebarWidth),

            styleBar.leadingAnchor.constraint(equalTo: toolSidebar.trailingAnchor),
            styleBar.topAnchor.constraint(equalTo: contentView.topAnchor),
            styleBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            scrollView.leadingAnchor.constraint(equalTo: toolSidebar.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: styleBar.bottomAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: statusBar.topAnchor),

            statusBar.leadingAnchor.constraint(equalTo: toolSidebar.trailingAnchor, constant: 4),
            statusBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            statusBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: statusBarHeight),
        ])
    }

    private func setupCanvas(image: NSImage) {
        canvasView.frame = NSRect(origin: .zero, size: image.size)
        canvasView.backgroundImage = image
        canvasView.delegate = self
        canvasView.setupUndoManager()
        scrollView.documentView = canvasView
    }

    private func loadStyleFromPreferences() {
        let prefs = Preferences.shared
        canvasView.currentStyle.strokeColor = prefs.defaultStrokeColor
        canvasView.currentStyle.fillColor = prefs.defaultFillColor
        canvasView.currentStyle.strokeWidth = prefs.defaultStrokeWidth
        canvasView.currentStyle.fontSize = prefs.defaultFontSize
        canvasView.currentStyle.fontName = prefs.defaultFontName
        canvasView.currentStyle.fontBold = prefs.defaultFontBold
        canvasView.currentStyle.fontItalic = prefs.defaultFontItalic
        canvasView.currentStyle.fontUnderline = prefs.defaultFontUnderline
        canvasView.currentStyle.opacity = prefs.defaultOpacity
        canvasView.currentStyle.shadow = prefs.defaultShadowEnabled ? .default : .none
        if let pattern = DashPattern(rawValue: prefs.defaultDashPattern) {
            canvasView.currentStyle.dashPattern = pattern
        }
        let alignTag = prefs.defaultTextAlignment
        canvasView.currentStyle.textHorizontalAlignment = alignTag == 0 ? .left : (alignTag == 2 ? .right : .center)
    }

    private func setupToolbar() {
        loadStyleFromPreferences()
        setupStyleControls()
        setupStyleBar()

        toolbar = NSToolbar(identifier: "EditorToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
        window?.toolbar = toolbar
    }

    private func setupStyleBar() {
        styleBar.orientation = .horizontal
        styleBar.spacing = 12
        styleBar.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        styleBar.alignment = .centerY
        styleBar.translatesAutoresizingMaskIntoConstraints = false
        styleBar.wantsLayer = true
        styleBar.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor

        styleBar.addArrangedSubview(makeControlGroup("Contour", strokeColorWell))
        styleBar.addArrangedSubview(makeControlGroup("Fond", fillColorWell))
        styleBar.addArrangedSubview(makeControlGroup("Épaisseur", widthPopup))
        styleBar.addArrangedSubview(makeControlGroup("Trait", dashPatternPopup))
        styleBar.addArrangedSubview(makeControlGroup("Coins", cornerRadiusPopup))
        styleBar.addArrangedSubview(makeControlGroup("Police", fontNamePopup))
        styleBar.addArrangedSubview(makeControlGroup("Taille", fontSizePopup))
        styleBar.addArrangedSubview(makeControlGroup("Style", fontStyleContainer))
        styleBar.addArrangedSubview(makeControlGroup("Alignement", textAlignPopup))
        styleBar.addArrangedSubview(makeControlGroup("Pointes", arrowHeadPopup))
        styleBar.addArrangedSubview(makeControlGroup("Taille pixel", pixelSizePopup))
        styleBar.addArrangedSubview(makeControlGroup("Flou", blurRadiusPopup))
        styleBar.addArrangedSubview(makeControlGroup("Début #", startNumberContainer))
        styleBar.addArrangedSubview(makeControlGroup("Opacité", opacitySlider))
    }

    private func makeControlGroup(_ label: String, _ control: NSView) -> NSStackView {
        let labelView = NSTextField(labelWithString: label)
        labelView.font = .systemFont(ofSize: 9)
        labelView.textColor = .secondaryLabelColor
        labelView.alignment = .center
        let group = NSStackView(views: [labelView, control])
        group.orientation = .vertical
        group.spacing = 2
        group.alignment = .centerX
        return group
    }

    private func setupStyleControls() {
        strokeColorWell.color = canvasView.currentStyle.strokeColor
        strokeColorWell.toolTip = "Couleur de contour"
        strokeColorWell.target = self
        strokeColorWell.action = #selector(strokeColorChanged(_:))

        fillColorWell.color = canvasView.currentStyle.fillColor
        fillColorWell.toolTip = "Couleur de fond"
        fillColorWell.target = self
        fillColorWell.action = #selector(fillColorChanged(_:))

        let widths: [CGFloat] = [0, 1, 2, 3, 5, 8, 12]
        for w in widths {
            widthPopup.addItem(withTitle: "\(Int(w)) pt")
            widthPopup.lastItem?.tag = Int(w)
        }
        selectWidthInPopup(canvasView.currentStyle.strokeWidth)
        widthPopup.toolTip = "Épaisseur de trait"
        widthPopup.target = self
        widthPopup.action = #selector(widthChanged(_:))

        // Font size popup for text annotations
        let fontSizes: [CGFloat] = [8, 10, 12, 14, 16, 18, 20, 24, 28, 32, 36, 48, 64]
        for fs in fontSizes {
            fontSizePopup.addItem(withTitle: "\(Int(fs)) pt")
            fontSizePopup.lastItem?.tag = Int(fs)
        }
        selectFontSizeInPopup(canvasView.currentStyle.fontSize)
        fontSizePopup.toolTip = "Taille de police"
        fontSizePopup.target = self
        fontSizePopup.action = #selector(fontSizeChanged(_:))
        fontSizePopup.isHidden = true

        // Bold / Italic toggle buttons
        boldButton.bezelStyle = .toolbar
        boldButton.setButtonType(.toggle)
        boldButton.image = NSImage(systemSymbolName: "bold", accessibilityDescription: "Gras")
        boldButton.toolTip = "Gras"
        boldButton.imagePosition = .imageOnly
        boldButton.target = self
        boldButton.action = #selector(boldChanged(_:))

        italicButton.bezelStyle = .toolbar
        italicButton.setButtonType(.toggle)
        italicButton.image = NSImage(systemSymbolName: "italic", accessibilityDescription: "Italique")
        italicButton.toolTip = "Italique"
        italicButton.imagePosition = .imageOnly
        italicButton.target = self
        italicButton.action = #selector(italicChanged(_:))

        fontStyleContainer.orientation = .horizontal
        fontStyleContainer.spacing = 2
        fontStyleContainer.addArrangedSubview(boldButton)
        fontStyleContainer.addArrangedSubview(italicButton)
        fontStyleContainer.isHidden = true

        // Arrow head style popup
        let arrowHeadItems: [(String, Int)] = [
            ("Fin →", 0), ("Début ←", 1), ("Les deux ↔", 2), ("Aucune —", 3)
        ]
        for (title, tag) in arrowHeadItems {
            arrowHeadPopup.addItem(withTitle: title)
            arrowHeadPopup.lastItem?.tag = tag
        }
        arrowHeadPopup.toolTip = "Pointes de flèche"
        arrowHeadPopup.target = self
        arrowHeadPopup.action = #selector(arrowHeadChanged(_:))
        arrowHeadPopup.isHidden = true

        let pixelSizes = [3, 5, 7, 9, 12, 15, 20]
        for ps in pixelSizes {
            pixelSizePopup.addItem(withTitle: "\(ps) px")
            pixelSizePopup.lastItem?.tag = ps
        }
        // Default to 5px
        if let item = pixelSizePopup.itemArray.first(where: { $0.tag == 5 }) {
            pixelSizePopup.select(item)
        }
        pixelSizePopup.toolTip = "Taille pixel"
        pixelSizePopup.target = self
        pixelSizePopup.action = #selector(pixelSizeChanged(_:))
        pixelSizePopup.isHidden = true

        // Blur radius popup for obfuscate filter
        let blurRadii = [3, 5, 8, 10, 15, 20, 30]
        for br in blurRadii {
            blurRadiusPopup.addItem(withTitle: "\(br) px")
            blurRadiusPopup.lastItem?.tag = br
        }
        if let item = blurRadiusPopup.itemArray.first(where: { $0.tag == 10 }) {
            blurRadiusPopup.select(item)
        }
        blurRadiusPopup.toolTip = "Rayon de flou"
        blurRadiusPopup.target = self
        blurRadiusPopup.action = #selector(blurRadiusChanged(_:))
        blurRadiusPopup.isHidden = true

        // Dash pattern popup (Loop 27)
        let dashItems: [(String, Int)] = [("Continu", 0), ("Tirets", 1), ("Points", 2)]
        for (title, tag) in dashItems {
            dashPatternPopup.addItem(withTitle: title)
            dashPatternPopup.lastItem?.tag = tag
        }
        dashPatternPopup.toolTip = "Style de trait"
        dashPatternPopup.target = self
        dashPatternPopup.action = #selector(dashPatternChanged(_:))
        dashPatternPopup.isHidden = true

        // Corner radius popup (Loop 28)
        let radii = [0, 5, 10, 15, 20, 30]
        for r in radii {
            cornerRadiusPopup.addItem(withTitle: r == 0 ? "Droit" : "\(r) px")
            cornerRadiusPopup.lastItem?.tag = r
        }
        cornerRadiusPopup.toolTip = "Rayon des coins"
        cornerRadiusPopup.target = self
        cornerRadiusPopup.action = #selector(cornerRadiusChanged(_:))
        cornerRadiusPopup.isHidden = true

        // Opacity slider (Loop 31)
        opacitySlider.toolTip = "Opacité"
        opacitySlider.target = self
        opacitySlider.action = #selector(opacityChanged(_:))
        opacitySlider.isHidden = true
        opacitySlider.controlSize = .small
        opacitySlider.widthAnchor.constraint(equalToConstant: 80).isActive = true

        // Font name popup (Loop 32)
        let fontNames = ["Helvetica", "Arial", "Courier", "Georgia", "Times New Roman", "Verdana", "Menlo"]
        for name in fontNames {
            fontNamePopup.addItem(withTitle: name)
        }
        fontNamePopup.toolTip = "Nom de police"
        fontNamePopup.target = self
        fontNamePopup.action = #selector(fontNameChanged(_:))
        fontNamePopup.isHidden = true
        if let item = fontNamePopup.itemArray.first(where: { $0.title == canvasView.currentStyle.fontName }) {
            fontNamePopup.select(item)
        }

        // Underline button (Loop 40)
        underlineButton.bezelStyle = .toolbar
        underlineButton.setButtonType(.toggle)
        underlineButton.image = NSImage(systemSymbolName: "underline", accessibilityDescription: "Souligné")
        underlineButton.toolTip = "Souligné"
        underlineButton.imagePosition = .imageOnly
        underlineButton.target = self
        underlineButton.action = #selector(underlineChanged(_:))

        fontStyleContainer.addArrangedSubview(underlineButton)

        // Text alignment popup (Loop 53)
        let alignItems: [(String, Int)] = [("Gauche", 0), ("Centre", 1), ("Droite", 2)]
        for (title, tag) in alignItems {
            textAlignPopup.addItem(withTitle: title)
            textAlignPopup.lastItem?.tag = tag
        }
        textAlignPopup.selectItem(at: 1) // Default center
        textAlignPopup.toolTip = "Alignement du texte"
        textAlignPopup.target = self
        textAlignPopup.action = #selector(textAlignChanged(_:))
        textAlignPopup.isHidden = true

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

    @objc private func fontSizeChanged(_ sender: NSPopUpButton) {
        guard !isUpdatingControls else { return }
        let size = CGFloat(sender.selectedItem?.tag ?? 14)
        canvasView.currentStyle.fontSize = size
        applyFontStyleToSelectedAnnotation()
        Preferences.shared.defaultFontSize = size
    }

    @objc private func boldChanged(_ sender: NSButton) {
        guard !isUpdatingControls else { return }
        canvasView.currentStyle.fontBold = (sender.state == .on)
        applyFontStyleToSelectedAnnotation()
        Preferences.shared.defaultFontBold = canvasView.currentStyle.fontBold
    }

    @objc private func italicChanged(_ sender: NSButton) {
        guard !isUpdatingControls else { return }
        canvasView.currentStyle.fontItalic = (sender.state == .on)
        applyFontStyleToSelectedAnnotation()
        Preferences.shared.defaultFontItalic = canvasView.currentStyle.fontItalic
    }

    @objc private func arrowHeadChanged(_ sender: NSPopUpButton) {
        guard !isUpdatingControls else { return }
        guard let arrow = canvasView.selectedAnnotation as? ArrowAnnotation else { return }
        let oldHeads = arrow.arrowHeads
        let tag = sender.selectedItem?.tag ?? 0
        switch tag {
        case 0: arrow.arrowHeads = .endPoint
        case 1: arrow.arrowHeads = .startPoint
        case 2: arrow.arrowHeads = .both
        case 3: arrow.arrowHeads = .none
        default: break
        }
        let newHeads = arrow.arrowHeads
        canvasView.annotationUndoManager.recordPropertyChange(arrow) {
            arrow.arrowHeads = oldHeads
        } redo: {
            arrow.arrowHeads = newHeads
        }
        canvasView.needsDisplay = true
    }

    @objc private func blurRadiusChanged(_ sender: NSPopUpButton) {
        guard !isUpdatingControls else { return }
        let newRadius = sender.selectedItem?.tag ?? 10
        if let of = canvasView.selectedAnnotation as? ObfuscateFilter {
            let oldRadius = of.blurRadius
            of.blurRadius = newRadius
            canvasView.annotationUndoManager.recordPropertyChange(of) {
                of.blurRadius = oldRadius
            } redo: {
                of.blurRadius = newRadius
            }
            canvasView.needsDisplay = true
        }
    }

    @objc private func dashPatternChanged(_ sender: NSPopUpButton) {
        guard !isUpdatingControls else { return }
        let tag = sender.selectedItem?.tag ?? 0
        let pattern: DashPattern = tag == 1 ? .dashed : (tag == 2 ? .dotted : .solid)
        canvasView.currentStyle.dashPattern = pattern
        applyDashPatternToSelectedAnnotation(pattern)
        Preferences.shared.defaultDashPattern = pattern.rawValue
    }

    private func applyDashPatternToSelectedAnnotation(_ pattern: DashPattern) {
        guard let annotation = canvasView.selectedAnnotation else { return }
        let tool = toolType(for: annotation)
        guard tool.supportsDashPattern else { return }
        let oldBounds = annotation.bounds
        let oldStyle = annotation.style
        annotation.style.dashPattern = pattern
        if annotation.style != oldStyle {
            canvasView.annotationUndoManager.recordModify(annotation, oldBounds: oldBounds, oldStyle: oldStyle)
            canvasView.needsDisplay = true
        }
    }

    @objc private func cornerRadiusChanged(_ sender: NSPopUpButton) {
        guard !isUpdatingControls else { return }
        let newRadius = CGFloat(sender.selectedItem?.tag ?? 0)
        if let rect = canvasView.selectedAnnotation as? RectangleAnnotation {
            let oldRadius = rect.cornerRadius
            rect.cornerRadius = newRadius
            canvasView.annotationUndoManager.recordPropertyChange(rect) {
                rect.cornerRadius = oldRadius
            } redo: {
                rect.cornerRadius = newRadius
            }
            canvasView.needsDisplay = true
        }
    }

    @objc private func opacityChanged(_ sender: NSSlider) {
        guard !isUpdatingControls else { return }
        let opacity = CGFloat(sender.doubleValue)
        canvasView.currentStyle.opacity = opacity
        Preferences.shared.defaultOpacity = opacity
        guard let annotation = canvasView.selectedAnnotation else { return }
        let tool = toolType(for: annotation)
        guard tool.supportsOpacity else { return }
        let oldBounds = annotation.bounds
        let oldStyle = annotation.style
        annotation.style.opacity = opacity
        if annotation.style != oldStyle {
            canvasView.annotationUndoManager.recordModify(annotation, oldBounds: oldBounds, oldStyle: oldStyle)
            canvasView.needsDisplay = true
        }
    }

    @objc private func fontNameChanged(_ sender: NSPopUpButton) {
        guard !isUpdatingControls else { return }
        let name = sender.selectedItem?.title ?? "Helvetica"
        canvasView.currentStyle.fontName = name
        applyFontStyleToSelectedAnnotation()
        Preferences.shared.defaultFontName = name
    }

    @objc private func underlineChanged(_ sender: NSButton) {
        guard !isUpdatingControls else { return }
        canvasView.currentStyle.fontUnderline = (sender.state == .on)
        applyFontStyleToSelectedAnnotation()
        Preferences.shared.defaultFontUnderline = canvasView.currentStyle.fontUnderline
    }

    @objc private func textAlignChanged(_ sender: NSPopUpButton) {
        guard !isUpdatingControls else { return }
        let tag = sender.selectedItem?.tag ?? 1
        let alignment: TextHorizontalAlignment = tag == 0 ? .left : (tag == 2 ? .right : .center)
        canvasView.currentStyle.textHorizontalAlignment = alignment
        applyFontStyleToSelectedAnnotation()
        Preferences.shared.defaultTextAlignment = tag
    }

    private func applyFontStyleToSelectedAnnotation() {
        guard let annotation = canvasView.selectedAnnotation else { return }
        let tool = toolType(for: annotation)
        guard tool.supportsFontSize || tool.supportsFontStyle else { return }

        let oldBounds = annotation.bounds
        let oldStyle = annotation.style

        annotation.style.fontSize = canvasView.currentStyle.fontSize
        annotation.style.fontName = canvasView.currentStyle.fontName
        annotation.style.fontBold = canvasView.currentStyle.fontBold
        annotation.style.fontItalic = canvasView.currentStyle.fontItalic
        annotation.style.fontUnderline = canvasView.currentStyle.fontUnderline
        annotation.style.textHorizontalAlignment = canvasView.currentStyle.textHorizontalAlignment

        if annotation.style != oldStyle {
            canvasView.annotationUndoManager.recordModify(annotation, oldBounds: oldBounds, oldStyle: oldStyle)
            canvasView.needsDisplay = true
        }
    }

    private func selectFontSizeInPopup(_ size: CGFloat) {
        let tag = Int(size)
        if let item = fontSizePopup.itemArray.first(where: { $0.tag == tag }) {
            fontSizePopup.select(item)
        } else {
            let closest = fontSizePopup.itemArray.min(by: { abs($0.tag - tag) < abs($1.tag - tag) })
            if let closest { fontSizePopup.select(closest) }
        }
    }

    @objc private func pixelSizeChanged(_ sender: NSPopUpButton) {
        guard !isUpdatingControls else { return }
        let newSize = sender.selectedItem?.tag ?? 5
        if let pf = canvasView.selectedAnnotation as? PixelateFilter {
            let oldSize = pf.pixelSize
            pf.pixelSize = newSize
            canvasView.annotationUndoManager.recordPropertyChange(pf) {
                pf.pixelSize = oldSize
            } redo: {
                pf.pixelSize = newSize
            }
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

        // Hide/show the control groups (parent stack views) in the style bar
        strokeColorWell.superview?.isHidden = !tool.supportsStrokeColor
        fillColorWell.superview?.isHidden = !tool.supportsFillColor
        widthPopup.superview?.isHidden = !tool.supportsStrokeWidth
        dashPatternPopup.superview?.isHidden = !tool.supportsDashPattern
        cornerRadiusPopup.superview?.isHidden = !tool.supportsCornerRadius
        opacitySlider.superview?.isHidden = !tool.supportsOpacity
        fontNamePopup.superview?.isHidden = !tool.supportsFontSize
        fontSizePopup.superview?.isHidden = !tool.supportsFontSize
        fontStyleContainer.superview?.isHidden = !tool.supportsFontStyle
        textAlignPopup.superview?.isHidden = !tool.supportsTextAlignment
        arrowHeadPopup.superview?.isHidden = !tool.supportsArrowHeads
        pixelSizePopup.superview?.isHidden = !tool.supportsPixelSize
        blurRadiusPopup.superview?.isHidden = !tool.supportsBlurRadius
        startNumberContainer.superview?.isHidden = !tool.supportsStartNumber

        if tool.supportsStrokeColor {
            strokeColorWell.color = style.strokeColor
        }
        if tool.supportsFillColor {
            fillColorWell.color = style.fillColor
        }
        if tool.supportsStrokeWidth {
            selectWidthInPopup(style.strokeWidth)
        }
        if tool.supportsDashPattern {
            let tag: Int
            switch style.dashPattern {
            case .solid: tag = 0
            case .dashed: tag = 1
            case .dotted: tag = 2
            }
            if let item = dashPatternPopup.itemArray.first(where: { $0.tag == tag }) {
                dashPatternPopup.select(item)
            }
        }
        if tool.supportsCornerRadius, let rect = canvasView.selectedAnnotation as? RectangleAnnotation {
            let tag = Int(rect.cornerRadius)
            if let item = cornerRadiusPopup.itemArray.first(where: { $0.tag == tag }) {
                cornerRadiusPopup.select(item)
            } else {
                let closest = cornerRadiusPopup.itemArray.min(by: { abs($0.tag - tag) < abs($1.tag - tag) })
                if let closest { cornerRadiusPopup.select(closest) }
            }
        }
        if tool.supportsOpacity {
            opacitySlider.doubleValue = Double(style.opacity)
        }
        if tool.supportsFontSize {
            selectFontSizeInPopup(style.fontSize)
            if let item = fontNamePopup.itemArray.first(where: { $0.title == style.fontName }) {
                fontNamePopup.select(item)
            }
        }
        if tool.supportsFontStyle {
            boldButton.state = style.fontBold ? .on : .off
            italicButton.state = style.fontItalic ? .on : .off
            underlineButton.state = style.fontUnderline ? .on : .off
        }
        if tool.supportsTextAlignment {
            let tag: Int
            switch style.textHorizontalAlignment {
            case .left: tag = 0
            case .center: tag = 1
            case .right: tag = 2
            }
            if let item = textAlignPopup.itemArray.first(where: { $0.tag == tag }) {
                textAlignPopup.select(item)
            }
        }
        if tool.supportsArrowHeads, let arrow = canvasView.selectedAnnotation as? ArrowAnnotation {
            let tag: Int
            switch arrow.arrowHeads {
            case .endPoint: tag = 0
            case .startPoint: tag = 1
            case .both: tag = 2
            case .none: tag = 3
            }
            if let item = arrowHeadPopup.itemArray.first(where: { $0.tag == tag }) {
                arrowHeadPopup.select(item)
            }
        }
        if tool.supportsPixelSize, let pf = canvasView.selectedAnnotation as? PixelateFilter {
            selectPixelSizeInPopup(pf.pixelSize)
        }
        if tool.supportsBlurRadius, let of = canvasView.selectedAnnotation as? ObfuscateFilter {
            if let item = blurRadiusPopup.itemArray.first(where: { $0.tag == of.blurRadius }) {
                blurRadiusPopup.select(item)
            }
        }
        if tool.supportsStartNumber {
            let current = StepLabelAnnotation.currentCounter
            startNumberStepper.integerValue = current
            startNumberLabel.stringValue = "\(current)"
        }

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

    @objc func zoomToFit(_ sender: Any?) {
        guard let imageSize = canvasView.backgroundImage?.size else { return }
        let visibleSize = scrollView.contentSize
        let scaleX = visibleSize.width / imageSize.width
        let scaleY = visibleSize.height / imageSize.height
        let scale = min(scaleX, scaleY)
        scrollView.magnification = max(scrollView.minMagnification, min(scale, scrollView.maxMagnification))
    }

    @objc func resetZoom(_ sender: Any?) {
        scrollView.magnification = 1.0
    }

    @objc private func performUndo(_ sender: Any?) {
        canvasView.annotationUndoManager.nsUndoManager.undo()
        canvasView.needsDisplay = true
        updateWindowTitle()
    }

    @objc private func performRedo(_ sender: Any?) {
        canvasView.annotationUndoManager.nsUndoManager.redo()
        canvasView.needsDisplay = true
        updateWindowTitle()
    }

    @objc func quickExport(_ sender: Any?) {
        guard let image = canvasView.renderFinalImage() else { return }
        let exportDir = Preferences.shared.screenshotFolder
        if let url = FileExporter.quickSave(image: image, to: exportDir) {
            // Brief flash in title to confirm
            let oldTitle = window?.title ?? ""
            window?.title = "Exporté: \(url.lastPathComponent)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.updateWindowTitle()
                _ = oldTitle
            }
        }
    }

    @objc func printDocument(_ sender: Any?) {
        guard let image = canvasView.renderFinalImage() else { return }
        let imageView = NSImageView(frame: NSRect(origin: .zero, size: image.size))
        imageView.image = image
        let printOperation = NSPrintOperation(view: imageView)
        printOperation.runModal(for: window!, delegate: nil, didRun: nil, contextInfo: nil)
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
        updateWindowTitle()
    }

    private func updateWindowTitle() {
        let baseName = sourceURL?.lastPathComponent ?? "Sans titre"
        let count = canvasView.annotations.count
        var title = baseName
        // Show image dimensions
        if let size = canvasView.backgroundImage?.size {
            title += " (\(Int(size.width))×\(Int(size.height)))"
        }
        if count > 0 {
            title += " — \(count) annotation\(count > 1 ? "s" : "")"
        }
        window?.title = title
    }

    func canvasView(_ canvas: CanvasView, mouseMovedTo point: CGPoint) {
        statusBar.stringValue = "X: \(Int(point.x))  Y: \(Int(point.y))"
    }

    func canvasView(_ canvas: CanvasView, didChangeCurrentTool tool: AnnotationTool) {
        toolSidebar.selectTool(tool)
        if let annotation = canvas.selectedAnnotation {
            let annotTool = toolType(for: annotation)
            updateStyleControls(for: annotTool, style: annotation.style)
        } else {
            updateStyleControls(for: tool, style: canvas.currentStyle)
        }
    }
}

// MARK: - NSToolbarDelegate

extension EditorWindowController: NSToolbarDelegate {
    private static let shadowId = NSToolbarItem.Identifier("shadow")
    private static let undoId = NSToolbarItem.Identifier("undo")
    private static let redoId = NSToolbarItem.Identifier("redo")
    private static let copyId = NSToolbarItem.Identifier("copyClipboard")
    private static let saveId = NSToolbarItem.Identifier("saveFile")

    static let toolbarIdentifiers: [NSToolbarItem.Identifier] = [
        shadowId,
        .flexibleSpace,
        undoId, redoId,
        copyId, saveId,
    ]

    static let toolbarLabels: [NSToolbarItem.Identifier: String] = [
        shadowId: "Ombre",
        undoId: "Annuler",
        redoId: "Rétablir",
        copyId: "Copier",
        saveId: "Enregistrer",
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
        case Self.shadowId:
            item.image = NSImage(systemSymbolName: "shadow", accessibilityDescription: "Ombre")
            item.target = self
            item.action = #selector(toggleShadow)
        case Self.undoId:
            item.image = NSImage(systemSymbolName: "arrow.uturn.backward", accessibilityDescription: "Annuler")
            item.target = self
            item.action = #selector(performUndo)
        case Self.redoId:
            item.image = NSImage(systemSymbolName: "arrow.uturn.forward", accessibilityDescription: "Rétablir")
            item.target = self
            item.action = #selector(performRedo)
        case Self.copyId:
            item.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Copier")
            item.target = self
            item.action = #selector(copyToClipboard)
        case Self.saveId:
            item.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: "Enregistrer")
            item.target = self
            item.action = #selector(saveToFile)
        default:
            break
        }

        return item
    }
}
