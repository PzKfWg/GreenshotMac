import AppKit

@MainActor
protocol CanvasViewDelegate: AnyObject {
    func canvasView(_ canvas: CanvasView, didSelectAnnotation annotation: Annotation?)
    func canvasView(_ canvas: CanvasView, didChangeCurrentTool tool: AnnotationTool)
    func canvasView(_ canvas: CanvasView, mouseMovedTo point: CGPoint)
}

@MainActor
final class CanvasView: NSView {
    var backgroundImage: NSImage? {
        didSet { needsDisplay = true }
    }

    weak var delegate: CanvasViewDelegate?

    private(set) var annotations: [Annotation] = []
    private(set) var selectedAnnotation: Annotation?
    private var activeHandle: HandlePosition?
    private var dragStart: CGPoint = .zero
    private var dragOldBounds: CGRect = .zero
    private var dragOldStyle: AnnotationStyle?
    private var dragOldTailPoint: CGPoint?
    private var isCreatingAnnotation = false
    private var isDraggingTail = false

    var currentTool: AnnotationTool = .select {
        didSet {
            delegate?.canvasView(self, didChangeCurrentTool: currentTool)
            window?.invalidateCursorRects(for: self)
            if currentTool != .select {
                Preferences.shared.lastUsedTool = currentTool.rawValue
            }
        }
    }
    var currentStyle: AnnotationStyle = AnnotationStyle()

    private(set) var annotationUndoManager: AnnotationUndoManager!

    override var undoManager: Foundation.UndoManager? {
        annotationUndoManager?.nsUndoManager
    }

    override var isFlipped: Bool { true }

    override var acceptsFirstResponder: Bool { true }

    func setupUndoManager() {
        annotationUndoManager = AnnotationUndoManager(canvas: self)
        // Apply saved preferences to the initial style
        currentStyle.strokeColor = Preferences.shared.defaultStrokeColor
        currentStyle.fillColor = Preferences.shared.defaultFillColor
        currentStyle.strokeWidth = Preferences.shared.defaultStrokeWidth
        currentStyle.shadow = Preferences.shared.defaultShadowEnabled ? .default : .none
        currentStyle.fontSize = Preferences.shared.defaultFontSize
        currentStyle.fontBold = Preferences.shared.defaultFontBold
        currentStyle.fontItalic = Preferences.shared.defaultFontItalic
    }

    // MARK: - Annotation Management

    func addAnnotation(_ annotation: Annotation, isUndoAction: Bool = false) {
        annotations.append(annotation)
        if !isUndoAction {
            annotationUndoManager.recordAdd(annotation)
        }
        needsDisplay = true
    }

    func insertAnnotation(_ annotation: Annotation, at index: Int, isUndoAction: Bool = false) {
        let safeIndex = min(index, annotations.count)
        annotations.insert(annotation, at: safeIndex)
        if !isUndoAction {
            annotationUndoManager.recordAdd(annotation)
        }
        needsDisplay = true
    }

    func removeAnnotation(_ annotation: Annotation, isUndoAction: Bool = false) {
        guard let index = annotations.firstIndex(where: { $0.id == annotation.id }) else { return }
        if !isUndoAction {
            annotationUndoManager.recordRemove(annotation, at: index)
        }
        annotations.remove(at: index)
        if selectedAnnotation?.id == annotation.id {
            selectedAnnotation = nil
        }
        needsDisplay = true
    }

    func selectAnnotation(_ annotation: Annotation?) {
        selectedAnnotation?.isSelected = false
        selectedAnnotation = annotation
        annotation?.isSelected = true
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
        // Scroll to make annotation visible (Loop 78)
        if let annotation {
            scrollToVisible(annotation.bounds.insetBy(dx: -20, dy: -20))
        }
        delegate?.canvasView(self, didSelectAnnotation: annotation)
    }

    // MARK: - Z-order

    func bringToFront(_ annotation: Annotation) {
        guard let index = annotations.firstIndex(where: { $0.id == annotation.id }) else { return }
        let newIndex = annotations.count - 1
        guard index != newIndex else { return }
        annotations.remove(at: index)
        annotations.append(annotation)
        annotationUndoManager.recordReorder(annotation, from: index, to: newIndex)
        needsDisplay = true
    }

    func sendToBack(_ annotation: Annotation) {
        guard let index = annotations.firstIndex(where: { $0.id == annotation.id }) else { return }
        guard index != 0 else { return }
        annotations.remove(at: index)
        annotations.insert(annotation, at: 0)
        annotationUndoManager.recordReorder(annotation, from: index, to: 0)
        needsDisplay = true
    }

    func moveAnnotation(_ annotation: Annotation, from oldIndex: Int, to newIndex: Int) {
        guard let currentIndex = annotations.firstIndex(where: { $0.id == annotation.id }) else { return }
        annotations.remove(at: currentIndex)
        let safeIndex = min(newIndex, annotations.count)
        annotations.insert(annotation, at: safeIndex)
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Background
        context.setFillColor(NSColor.windowBackgroundColor.cgColor)
        context.fill(dirtyRect)

        // Checkerboard pattern for transparency (Loop 72)
        if let image = backgroundImage {
            let imageRect = CGRect(origin: .zero, size: image.size)
            drawCheckerboard(in: context, rect: imageRect)
            image.draw(in: imageRect)
        }

        // Assign background image to filter annotations before rendering
        for annotation in annotations {
            if let pf = annotation as? PixelateFilter {
                pf.backgroundImage = backgroundImage
            } else if let of = annotation as? ObfuscateFilter {
                of.backgroundImage = backgroundImage
            }
        }

        // Annotations
        for annotation in annotations {
            context.saveGState()
            annotation.draw(in: context)
            context.restoreGState()
        }
    }

    private func drawCheckerboard(in context: CGContext, rect: CGRect) {
        let tileSize: CGFloat = 10
        let lightColor = NSColor(white: 0.95, alpha: 1).cgColor
        let darkColor = NSColor(white: 0.85, alpha: 1).cgColor
        for row in 0..<Int(ceil(rect.height / tileSize)) {
            for col in 0..<Int(ceil(rect.width / tileSize)) {
                let color = (row + col) % 2 == 0 ? lightColor : darkColor
                context.setFillColor(color)
                let tileRect = CGRect(x: rect.origin.x + CGFloat(col) * tileSize,
                                      y: rect.origin.y + CGFloat(row) * tileSize,
                                      width: tileSize, height: tileSize)
                context.fill(tileRect.intersection(rect))
            }
        }
    }

    // MARK: - Rendering

    func renderFinalImage() -> NSImage? {
        guard let bgImage = backgroundImage else { return nil }
        let size = bgImage.size

        let wasSelected = selectedAnnotation
        selectAnnotation(nil)
        defer { if let was = wasSelected { selectAnnotation(was) } }

        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        bitmapRep.size = size

        guard let nsContext = NSGraphicsContext(bitmapImageRep: bitmapRep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext

        let cgContext = nsContext.cgContext

        // Draw background image in the unflipped bitmap context
        // (NSImage.draw handles orientation correctly when isFlipped matches the context)
        bgImage.draw(in: CGRect(origin: .zero, size: size))

        // Flip coordinate system for annotations (they use isFlipped=true coordinates)
        cgContext.translateBy(x: 0, y: size.height)
        cgContext.scaleBy(x: 1, y: -1)

        for annotation in annotations {
            if let pf = annotation as? PixelateFilter {
                pf.backgroundImage = bgImage
            } else if let of = annotation as? ObfuscateFilter {
                of.backgroundImage = bgImage
            }
            cgContext.saveGState()
            annotation.draw(in: cgContext)
            cgContext.restoreGState()
        }

        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        image.addRepresentation(bitmapRep)
        return image
    }

    // MARK: - Cursor

    override func resetCursorRects() {
        super.resetCursorRects()

        if currentTool == .select {
            // Add move cursor over selected annotation, resize cursors over handles
            if let sel = selectedAnnotation {
                for position in HandlePosition.allCases {
                    let handleRect = sel.handleRect(for: position)
                    let cursor: NSCursor
                    switch position {
                    case .topLeft, .bottomRight: cursor = .crosshair
                    case .topRight, .bottomLeft: cursor = .crosshair
                    case .topCenter, .bottomCenter: cursor = .resizeUpDown
                    case .middleLeft, .middleRight: cursor = .resizeLeftRight
                    }
                    addCursorRect(handleRect, cursor: cursor)
                }
                // Tail handle cursor for speech bubbles
                if let bubble = sel as? SpeechBubbleAnnotation {
                    let tailRect = CGRect(x: bubble.tailPoint.x - 8, y: bubble.tailPoint.y - 8, width: 16, height: 16)
                    addCursorRect(tailRect, cursor: .crosshair)
                }
                addCursorRect(sel.bounds, cursor: .openHand)
            }
            // Show pointing hand over non-selected annotations (Loop 79)
            for annotation in annotations where annotation.id != selectedAnnotation?.id {
                addCursorRect(annotation.bounds, cursor: .pointingHand)
            }
            addCursorRect(bounds, cursor: .arrow)
        } else {
            addCursorRect(bounds, cursor: .crosshair)
        }
    }

    // MARK: - Mouse Tracking (Loop 73)

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeInKeyWindow], owner: self, userInfo: nil)
        addTrackingArea(area)
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        delegate?.canvasView(self, mouseMovedTo: point)
    }

    // MARK: - Context Menu (Loop 41)

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        // Find annotation under cursor
        let targetAnnotation = annotations.reversed().first { $0.hitTest(point: point) }
        if let annotation = targetAnnotation {
            selectAnnotation(annotation)
            let menu = NSMenu()
            menu.addItem(withTitle: "Dupliquer", action: #selector(contextDuplicate(_:)), keyEquivalent: "")
            menu.addItem(withTitle: "Supprimer", action: #selector(contextDelete(_:)), keyEquivalent: "")
            menu.addItem(NSMenuItem.separator())
            menu.addItem(withTitle: "Amener devant", action: #selector(contextBringToFront(_:)), keyEquivalent: "")
            menu.addItem(withTitle: "Envoyer derrière", action: #selector(contextSendToBack(_:)), keyEquivalent: "")
            menu.addItem(withTitle: "Avancer d'un plan", action: #selector(contextBringForwardOne(_:)), keyEquivalent: "")
            menu.addItem(withTitle: "Reculer d'un plan", action: #selector(contextSendBackwardOne(_:)), keyEquivalent: "")
            for item in menu.items { item.target = self }
            return menu
        }
        return nil
    }

    @objc private func contextDuplicate(_ sender: Any?) { duplicateSelectedAnnotation() }
    @objc private func contextDelete(_ sender: Any?) {
        if let annotation = selectedAnnotation { removeAnnotation(annotation) }
    }
    @objc private func contextBringToFront(_ sender: Any?) {
        if let annotation = selectedAnnotation { bringToFront(annotation) }
    }
    @objc private func contextSendToBack(_ sender: Any?) {
        if let annotation = selectedAnnotation { sendToBack(annotation) }
    }
    @objc private func contextBringForwardOne(_ sender: Any?) {
        if let annotation = selectedAnnotation { bringForwardOne(annotation) }
    }
    @objc private func contextSendBackwardOne(_ sender: Any?) {
        if let annotation = selectedAnnotation { sendBackwardOne(annotation) }
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        // Commit any active inline text edit before processing the click
        if editingTextField != nil {
            commitTextEditing()
        }

        // Double-click on text annotation to edit (Loop 44)
        if event.clickCount == 2 {
            let point = convert(event.locationInWindow, from: nil)
            if let textAnnotation = annotations.reversed().first(where: { $0.hitTest(point: point) }) as? TextAnnotation {
                beginTextEditing(textAnnotation)
                return
            }
            if let bubble = annotations.reversed().first(where: { $0.hitTest(point: point) }) as? SpeechBubbleAnnotation {
                beginBubbleTextEditing(bubble)
                return
            }
        }

        let point = convert(event.locationInWindow, from: nil)

        switch currentTool {
        case .select:
            handleSelectMouseDown(point: point)
        case .rectangle, .ellipse, .line, .arrow, .freehand, .text, .speechBubble, .stepLabel, .pixelate, .highlight, .obfuscate:
            handleCreateMouseDown(point: point)
        case .crop:
            handleCreateMouseDown(point: point)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if isDraggingTail, let bubble = selectedAnnotation as? SpeechBubbleAnnotation {
            bubble.tailPoint = point
            needsDisplay = true
            return
        }
        if isCreatingAnnotation {
            handleCreateMouseDragged(point: point)
        } else if let annotation = selectedAnnotation {
            if let handle = activeHandle {
                var newBounds = handle.resize(bounds: dragOldBounds, to: point)
                // Shift-constrain: maintain aspect ratio during resize
                if NSEvent.modifierFlags.contains(.shift), dragOldBounds.width > 0, dragOldBounds.height > 0 {
                    let aspectRatio = dragOldBounds.width / dragOldBounds.height
                    let w = newBounds.width
                    let h = newBounds.height
                    if w / h > aspectRatio {
                        newBounds.size.width = h * aspectRatio
                    } else {
                        newBounds.size.height = w / aspectRatio
                    }
                }
                // Enforce minimum size of 20x20
                newBounds.size.width = max(newBounds.size.width, 20)
                newBounds.size.height = max(newBounds.size.height, 20)
                annotation.bounds = newBounds
                needsDisplay = true
            } else {
                var dx = point.x - dragStart.x
                var dy = point.y - dragStart.y
                // Shift+drag constrains movement to one axis (Loop 55)
                if NSEvent.modifierFlags.contains(.shift) {
                    if abs(dx) > abs(dy) { dy = 0 } else { dx = 0 }
                }
                var newBounds = dragOldBounds.offsetBy(dx: dx, dy: dy)
                // Snap to canvas edges (Loop 75)
                if let imageSize = backgroundImage?.size {
                    let snapThreshold: CGFloat = 8
                    // Snap left edge
                    if abs(newBounds.minX) < snapThreshold { newBounds.origin.x = 0 }
                    // Snap top edge
                    if abs(newBounds.minY) < snapThreshold { newBounds.origin.y = 0 }
                    // Snap right edge
                    if abs(newBounds.maxX - imageSize.width) < snapThreshold { newBounds.origin.x = imageSize.width - newBounds.width }
                    // Snap bottom edge
                    if abs(newBounds.maxY - imageSize.height) < snapThreshold { newBounds.origin.y = imageSize.height - newBounds.height }
                }
                annotation.bounds = newBounds
                // Move SpeechBubble tail along with the body
                if let bubble = annotation as? SpeechBubbleAnnotation, let oldTail = dragOldTailPoint {
                    bubble.tailPoint = CGPoint(x: oldTail.x + dx, y: oldTail.y + dy)
                }
                needsDisplay = true
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if isDraggingTail {
            if let bubble = selectedAnnotation as? SpeechBubbleAnnotation, let oldTail = dragOldTailPoint {
                if bubble.tailPoint != oldTail, let oldStyle = dragOldStyle {
                    annotationUndoManager.recordModify(bubble, oldBounds: dragOldBounds, oldStyle: oldStyle)
                }
            }
            isDraggingTail = false
            return
        }
        if isCreatingAnnotation {
            handleCreateMouseUp(point: point)
        } else if let annotation = selectedAnnotation {
            // Clamp annotation to stay at least partially visible on canvas
            if let imageSize = backgroundImage?.size {
                var b = annotation.bounds
                let minVisible: CGFloat = 20
                b.origin.x = max(-b.width + minVisible, min(b.origin.x, imageSize.width - minVisible))
                b.origin.y = max(-b.height + minVisible, min(b.origin.y, imageSize.height - minVisible))
                annotation.bounds = b
            }
            // Record undo for move/resize
            if annotation.bounds != dragOldBounds, let oldStyle = dragOldStyle {
                annotationUndoManager.recordModify(annotation, oldBounds: dragOldBounds, oldStyle: oldStyle)
            }
        }

        activeHandle = nil
        isCreatingAnnotation = false
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 51 || event.keyCode == 117 { // Delete or Forward Delete
            if let annotation = selectedAnnotation {
                removeAnnotation(annotation)
            }
        } else if event.keyCode == 53 { // Escape
            selectAnnotation(nil)
            currentTool = .select
        } else if event.keyCode == 123 || event.keyCode == 124 || event.keyCode == 125 || event.keyCode == 126 {
            // Arrow keys: nudge selected annotation
            if let annotation = selectedAnnotation {
                let step: CGFloat = event.modifierFlags.contains(.command) ? 50 : (event.modifierFlags.contains(.shift) ? 10 : 1)
                let oldBounds = annotation.bounds
                let oldStyle = annotation.style
                switch event.keyCode {
                case 123: annotation.bounds.origin.x -= step // Left
                case 124: annotation.bounds.origin.x += step // Right
                case 125: annotation.bounds.origin.y += step // Down (flipped)
                case 126: annotation.bounds.origin.y -= step // Up (flipped)
                default: break
                }
                annotationUndoManager.recordModify(annotation, oldBounds: oldBounds, oldStyle: oldStyle)
                needsDisplay = true
            }
        } else if event.keyCode == 2 && event.modifierFlags.contains(.command) { // Cmd+D
            duplicateSelectedAnnotation()
        } else if event.keyCode == 0 && event.modifierFlags.contains(.command) { // Cmd+A
            selectAllAnnotations()
        } else if event.keyCode == 8 && event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) { // Cmd+Shift+C
            NSApp.sendAction(#selector(EditorWindowController.copyToClipboard(_:)), to: nil, from: self)
        } else if event.keyCode == 8 && event.modifierFlags.contains(.command) { // Cmd+C
            copySelectedAnnotation()
        } else if event.keyCode == 9 && event.modifierFlags.contains(.command) { // Cmd+V
            pasteAnnotation()
        } else if event.keyCode == 30 && event.modifierFlags.contains(.command) { // Cmd+]
            if let annotation = selectedAnnotation { bringForwardOne(annotation) }
        } else if event.keyCode == 33 && event.modifierFlags.contains(.command) { // Cmd+[
            if let annotation = selectedAnnotation { sendBackwardOne(annotation) }
        } else if event.keyCode == 1 && event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) { // Cmd+Shift+S
            NSApp.sendAction(#selector(EditorWindowController.quickExport(_:)), to: nil, from: self)
        } else if event.keyCode == 1 && event.modifierFlags.contains(.command) { // Cmd+S
            NSApp.sendAction(#selector(EditorWindowController.saveToFile(_:)), to: nil, from: self)
        } else if event.keyCode == 35 && event.modifierFlags.contains(.command) { // Cmd+P
            NSApp.sendAction(#selector(EditorWindowController.printDocument(_:)), to: nil, from: self)
        } else if event.keyCode == 51 && event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) { // Cmd+Shift+Delete
            deleteAllAnnotations()
        } else if event.keyCode == 29 && event.modifierFlags.contains(.command) { // Cmd+0
            // Forward to responder chain (zoom to fit)
            NSApp.sendAction(#selector(EditorWindowController.zoomToFit(_:)), to: nil, from: self)
        } else if event.keyCode == 18 && event.modifierFlags.contains(.command) { // Cmd+1
            NSApp.sendAction(#selector(EditorWindowController.resetZoom(_:)), to: nil, from: self)
        } else if event.keyCode == 48 { // Tab
            cycleAnnotationSelection(reverse: event.modifierFlags.contains(.shift))
        } else if !event.modifierFlags.contains(.command), let chars = event.characters, chars.count == 1 {
            // Number keys to switch tools
            if let toolIndex = Self.numberKeyToolMap[chars] {
                let allTools = AnnotationTool.allCases
                if toolIndex < allTools.count {
                    currentTool = allTools[toolIndex]
                }
            } else {
                super.keyDown(with: event)
            }
        } else {
            super.keyDown(with: event)
        }
    }

    // Number key → tool index mapping (1=select, 2=rect, ..., 0=highlight)
    private static let numberKeyToolMap: [String: Int] = [
        "1": 0, "2": 1, "3": 2, "4": 3, "5": 4,
        "6": 5, "7": 6, "8": 7, "9": 8, "0": 9,
    ]

    // MARK: - Internal clipboard for copy/paste
    private static var clipboardAnnotation: Annotation?

    private func selectAllAnnotations() {
        // Select the last annotation (topmost) — multi-select not supported yet
        if let last = annotations.last {
            selectAnnotation(last)
        }
    }

    private func copySelectedAnnotation() {
        guard let annotation = selectedAnnotation else { return }
        Self.clipboardAnnotation = annotation.copy()
    }

    private func pasteAnnotation() {
        guard let original = Self.clipboardAnnotation else { return }
        let pasted = original.copy()
        pasted.bounds = pasted.bounds.offsetBy(dx: 20, dy: 20)
        pasted.isSelected = false
        addAnnotation(pasted)
        selectAnnotation(pasted)
        // Update clipboard so next paste offsets again
        Self.clipboardAnnotation = pasted.copy()
    }

    func bringForwardOne(_ annotation: Annotation) {
        guard let index = annotations.firstIndex(where: { $0.id == annotation.id }) else { return }
        let newIndex = index + 1
        guard newIndex < annotations.count else { return }
        annotations.remove(at: index)
        annotations.insert(annotation, at: newIndex)
        annotationUndoManager.recordReorder(annotation, from: index, to: newIndex)
        needsDisplay = true
    }

    func sendBackwardOne(_ annotation: Annotation) {
        guard let index = annotations.firstIndex(where: { $0.id == annotation.id }) else { return }
        guard index > 0 else { return }
        let newIndex = index - 1
        annotations.remove(at: index)
        annotations.insert(annotation, at: newIndex)
        annotationUndoManager.recordReorder(annotation, from: index, to: newIndex)
        needsDisplay = true
    }

    private func cycleAnnotationSelection(reverse: Bool) {
        guard !annotations.isEmpty else { return }
        if let current = selectedAnnotation,
           let currentIndex = annotations.firstIndex(where: { $0.id == current.id }) {
            let nextIndex: Int
            if reverse {
                nextIndex = currentIndex == 0 ? annotations.count - 1 : currentIndex - 1
            } else {
                nextIndex = (currentIndex + 1) % annotations.count
            }
            selectAnnotation(annotations[nextIndex])
        } else {
            selectAnnotation(annotations[reverse ? annotations.count - 1 : 0])
        }
    }

    private func flipSelectedAnnotationHorizontal() {
        guard let annotation = selectedAnnotation else { return }
        let oldBounds = annotation.bounds
        let oldStyle = annotation.style
        // Flip around horizontal center of canvas
        if let imageWidth = backgroundImage?.size.width {
            let newX = imageWidth - annotation.bounds.origin.x - annotation.bounds.width
            annotation.bounds.origin.x = newX
        }
        // Flip direction for line/arrow annotations
        if let line = annotation as? LineAnnotation {
            switch line.direction {
            case .topLeftToBottomRight: line.direction = .topRightToBottomLeft
            case .topRightToBottomLeft: line.direction = .topLeftToBottomRight
            case .bottomLeftToTopRight: line.direction = .bottomRightToTopLeft
            case .bottomRightToTopLeft: line.direction = .bottomLeftToTopRight
            }
        } else if let arrow = annotation as? ArrowAnnotation {
            switch arrow.direction {
            case .topLeftToBottomRight: arrow.direction = .topRightToBottomLeft
            case .topRightToBottomLeft: arrow.direction = .topLeftToBottomRight
            case .bottomLeftToTopRight: arrow.direction = .bottomRightToTopLeft
            case .bottomRightToTopLeft: arrow.direction = .bottomLeftToTopRight
            }
        }
        annotationUndoManager.recordModify(annotation, oldBounds: oldBounds, oldStyle: oldStyle)
        needsDisplay = true
    }

    private func deleteAllAnnotations() {
        guard !annotations.isEmpty else { return }
        selectAnnotation(nil)
        let allAnnotations = annotations
        for annotation in allAnnotations.reversed() {
            removeAnnotation(annotation)
        }
    }

    private func duplicateSelectedAnnotation() {
        guard let annotation = selectedAnnotation else { return }
        let duplicate = annotation.copy()
        duplicate.bounds = duplicate.bounds.offsetBy(dx: 10, dy: 10)
        duplicate.isSelected = false
        addAnnotation(duplicate)
        selectAnnotation(duplicate)
    }

    // MARK: - Select Tool

    private func handleSelectMouseDown(point: CGPoint) {
        // Check if clicking on speech bubble tail handle (Loop 74)
        if let bubble = selectedAnnotation as? SpeechBubbleAnnotation {
            let tailRect = CGRect(x: bubble.tailPoint.x - 8, y: bubble.tailPoint.y - 8, width: 16, height: 16)
            if tailRect.contains(point) {
                isDraggingTail = true
                dragStart = point
                dragOldBounds = bubble.bounds
                dragOldStyle = bubble.style
                dragOldTailPoint = bubble.tailPoint
                return
            }
        }
        // Check if clicking on a handle of the selected annotation
        if let sel = selectedAnnotation, let handle = sel.handleHitTest(point: point) {
            activeHandle = handle
            dragStart = point
            dragOldBounds = sel.bounds
            dragOldStyle = sel.style
            dragOldTailPoint = (sel as? SpeechBubbleAnnotation)?.tailPoint
            return
        }

        // Check annotations in reverse order (top-most first)
        for annotation in annotations.reversed() {
            if annotation.hitTest(point: point) {
                selectAnnotation(annotation)
                dragStart = point
                dragOldBounds = annotation.bounds
                dragOldStyle = annotation.style
                dragOldTailPoint = (annotation as? SpeechBubbleAnnotation)?.tailPoint
                return
            }
        }

        // Clicked on empty space
        selectAnnotation(nil)
    }

    // MARK: - Create Tool

    private var creationStartPoint: CGPoint = .zero
    private var creatingAnnotation: Annotation?

    private func handleCreateMouseDown(point: CGPoint) {
        // If clicking on the currently selected annotation, switch to select behavior (move/resize)
        if let selected = selectedAnnotation, selected.hitTest(point: point) {
            handleSelectMouseDown(point: point)
            return
        }
        // Also check handles of selected annotation
        if let selected = selectedAnnotation, selected.handleHitTest(point: point) != nil {
            handleSelectMouseDown(point: point)
            return
        }

        isCreatingAnnotation = true
        creationStartPoint = point
        let bounds = CGRect(origin: point, size: .zero)

        let annotation: Annotation
        switch currentTool {
        case .rectangle:
            annotation = RectangleAnnotation(bounds: bounds, style: currentStyle, cornerRadius: Preferences.shared.defaultCornerRadius)
        case .ellipse:
            annotation = EllipseAnnotation(bounds: bounds, style: currentStyle)
        case .line:
            annotation = LineAnnotation(bounds: bounds, style: currentStyle)
        case .arrow:
            annotation = ArrowAnnotation(bounds: bounds, style: currentStyle)
        case .text:
            let textAnnotation = TextAnnotation(bounds: CGRect(origin: point, size: CGSize(width: 150, height: 30)), style: currentStyle)
            annotation = textAnnotation
        case .speechBubble:
            let bubble = SpeechBubbleAnnotation(bounds: CGRect(origin: point, size: CGSize(width: 150, height: 60)), style: currentStyle, cornerRadius: Preferences.shared.defaultCornerRadius)
            annotation = bubble
        case .stepLabel:
            var stepStyle = currentStyle
            // strokeColor = circle background; use default DarkRed if it's the generic default
            if stepStyle.strokeColor == AnnotationStyle().strokeColor {
                stepStyle.strokeColor = StepLabelAnnotation.defaultStyle.strokeColor
            }
            // fillColor = number text color; use default white if clear
            if stepStyle.fillColor == .clear {
                stepStyle.fillColor = StepLabelAnnotation.defaultStyle.fillColor
            }
            stepStyle.shadow = StepLabelAnnotation.defaultStyle.shadow
            annotation = StepLabelAnnotation(center: point, style: stepStyle)
        case .freehand:
            annotation = FreehandAnnotation(points: [point], style: currentStyle)
        case .pixelate:
            let pf = PixelateFilter(bounds: bounds)
            pf.backgroundImage = backgroundImage
            pf.pixelSize = Preferences.shared.defaultPixelSize
            annotation = pf
        case .highlight:
            var highlightStyle = currentStyle
            // Default to yellow highlight if fill color is clear
            if highlightStyle.fillColor == .clear {
                highlightStyle.fillColor = NSColor.yellow.withAlphaComponent(0.4)
            }
            annotation = HighlightFilter(bounds: bounds, style: highlightStyle)
        case .obfuscate:
            let of = ObfuscateFilter(bounds: bounds)
            of.backgroundImage = backgroundImage
            of.blurRadius = Preferences.shared.defaultBlurRadius
            annotation = of
        case .crop:
            // Crop uses a temporary rectangle; actual crop applied on mouseUp
            var cropStyle = AnnotationStyle()
            cropStyle.strokeColor = .systemBlue
            cropStyle.fillColor = NSColor.systemBlue.withAlphaComponent(0.1)
            cropStyle.shadow = .none
            annotation = RectangleAnnotation(bounds: bounds, style: cropStyle)
        case .select:
            return
        }

        creatingAnnotation = annotation
        // Append directly — undo is recorded in handleCreateMouseUp after validation
        annotations.append(annotation)
        selectAnnotation(annotation)
        needsDisplay = true
    }

    private func handleCreateMouseDragged(point: CGPoint) {
        guard let annotation = creatingAnnotation else { return }

        // Freehand: just add points continuously
        if let freehand = annotation as? FreehandAnnotation {
            freehand.addPoint(point)
            needsDisplay = true
            return
        }

        var adjustedPoint = point
        let shiftHeld = NSEvent.modifierFlags.contains(.shift)

        if shiftHeld {
            let dx = point.x - creationStartPoint.x
            let dy = point.y - creationStartPoint.y

            if annotation is LineAnnotation || annotation is ArrowAnnotation {
                // Constrain to horizontal, vertical, or 45° diagonal
                let absDx = abs(dx)
                let absDy = abs(dy)
                let angle = atan2(absDy, absDx)
                if angle < .pi / 8 {
                    // Horizontal
                    adjustedPoint.y = creationStartPoint.y
                } else if angle > 3 * .pi / 8 {
                    // Vertical
                    adjustedPoint.x = creationStartPoint.x
                } else {
                    // 45° diagonal
                    let maxDim = max(absDx, absDy)
                    adjustedPoint.x = creationStartPoint.x + (dx > 0 ? maxDim : -maxDim)
                    adjustedPoint.y = creationStartPoint.y + (dy > 0 ? maxDim : -maxDim)
                }
            } else {
                // Constrain to square proportions
                let maxDim = max(abs(dx), abs(dy))
                adjustedPoint.x = creationStartPoint.x + (dx > 0 ? maxDim : -maxDim)
                adjustedPoint.y = creationStartPoint.y + (dy > 0 ? maxDim : -maxDim)
            }
        }

        annotation.bounds = CGRect(
            x: min(creationStartPoint.x, adjustedPoint.x),
            y: min(creationStartPoint.y, adjustedPoint.y),
            width: abs(adjustedPoint.x - creationStartPoint.x),
            height: abs(adjustedPoint.y - creationStartPoint.y)
        )

        // Track direction for line-based annotations (bounds normalization loses this info)
        let direction = DiagonalDirection.from(start: creationStartPoint, end: adjustedPoint)
        if let line = annotation as? LineAnnotation {
            line.direction = direction
        } else if let arrow = annotation as? ArrowAnnotation {
            arrow.direction = direction
        }

        needsDisplay = true
    }

    // MARK: - Inline Text Editing (Loop 44)

    private var editingTextField: NSTextField?
    private weak var editingAnnotation: TextAnnotation?
    private weak var editingBubble: SpeechBubbleAnnotation?

    private func beginTextEditing(_ annotation: TextAnnotation) {
        // Clean up any existing editing session first
        commitTextEditing()

        selectAnnotation(annotation)
        annotation.isEditing = true
        let field = NSTextField(frame: annotation.bounds)
        field.stringValue = annotation.text
        field.font = annotation.resolveFont()
        field.textColor = annotation.style.strokeColor
        field.backgroundColor = .clear
        field.isBordered = false
        field.focusRingType = .exterior
        field.alignment = .center
        field.delegate = self
        field.target = self
        field.action = #selector(textEditingAction(_:))
        addSubview(field)
        field.becomeFirstResponder()
        editingTextField = field
        editingAnnotation = annotation
        needsDisplay = true
    }

    private func beginBubbleTextEditing(_ bubble: SpeechBubbleAnnotation) {
        // Clean up any existing editing session first
        commitTextEditing()

        selectAnnotation(bubble)
        bubble.isEditing = true
        let field = NSTextField(frame: bubble.bounds.insetBy(dx: 8, dy: 8))
        field.stringValue = bubble.text
        field.font = NSFont(name: bubble.style.fontName, size: bubble.style.fontSize) ?? .systemFont(ofSize: bubble.style.fontSize)
        field.textColor = bubble.style.strokeColor
        field.backgroundColor = .clear
        field.isBordered = false
        field.focusRingType = .exterior
        field.alignment = .center
        field.delegate = self
        field.target = self
        field.action = #selector(textEditingAction(_:))
        addSubview(field)
        field.becomeFirstResponder()
        editingTextField = field
        editingBubble = bubble
        needsDisplay = true
    }

    @objc private func textEditingAction(_ sender: NSTextField) {
        commitTextEditing()
    }

    /// Commits the current inline text edit, updates the annotation, and cleans up the field.
    /// Safe to call even when no editing session is active.
    private func commitTextEditing() {
        guard let field = editingTextField else { return }
        if let annotation = editingAnnotation {
            let oldBounds = annotation.bounds
            let oldStyle = annotation.style
            annotation.text = field.stringValue
            annotation.isEditing = false
            annotationUndoManager.recordModify(annotation, oldBounds: oldBounds, oldStyle: oldStyle)
        }
        if let bubble = editingBubble {
            let oldBounds = bubble.bounds
            let oldStyle = bubble.style
            bubble.text = field.stringValue
            bubble.isEditing = false
            annotationUndoManager.recordModify(bubble, oldBounds: oldBounds, oldStyle: oldStyle)
        }
        field.removeFromSuperview()
        editingTextField = nil
        editingAnnotation = nil
        editingBubble = nil
        needsDisplay = true
    }

    private func handleCreateMouseUp(point: CGPoint) {
        guard let annotation = creatingAnnotation else { return }

        // If too small, remove it
        if annotation.bounds.width < 4 && annotation.bounds.height < 4 {
            annotations.removeAll { $0.id == annotation.id }
            creatingAnnotation = nil
            needsDisplay = true
            return
        }

        // Handle crop tool: apply crop and remove the temporary rectangle
        if currentTool == .crop {
            let cropRect = annotation.bounds
            annotations.removeAll { $0.id == annotation.id }
            CropTool.applyCrop(to: self, rect: cropRect)
            creatingAnnotation = nil
            currentTool = .select
            return
        }

        // Record undo (the annotation was already appended, now formalize it)
        annotationUndoManager.recordAdd(annotation)
        creatingAnnotation = nil

        // Tool stays active — user can create another annotation of the same type
    }
}

// MARK: - NSTextFieldDelegate (inline text editing commit on focus loss)

extension CanvasView: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        commitTextEditing()
    }
}
