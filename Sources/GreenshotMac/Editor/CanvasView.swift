import AppKit

@MainActor
protocol CanvasViewDelegate: AnyObject {
    func canvasView(_ canvas: CanvasView, didSelectAnnotation annotation: Annotation?)
    func canvasView(_ canvas: CanvasView, didChangeCurrentTool tool: AnnotationTool)
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
    private var isCreatingAnnotation = false

    var currentTool: AnnotationTool = .select {
        didSet { delegate?.canvasView(self, didChangeCurrentTool: currentTool) }
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
        delegate?.canvasView(self, didSelectAnnotation: annotation)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Background
        context.setFillColor(NSColor.windowBackgroundColor.cgColor)
        context.fill(dirtyRect)

        // Image
        if let image = backgroundImage {
            let imageRect = CGRect(origin: .zero, size: image.size)
            image.draw(in: imageRect)
        }

        // Assign background image to pixelate filters before rendering
        for annotation in annotations {
            if let pf = annotation as? PixelateFilter {
                pf.backgroundImage = backgroundImage
            }
        }

        // Annotations
        for annotation in annotations {
            context.saveGState()
            annotation.draw(in: context)
            context.restoreGState()
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

        // Flip coordinate system to match isFlipped=true
        cgContext.translateBy(x: 0, y: size.height)
        cgContext.scaleBy(x: 1, y: -1)

        bgImage.draw(in: CGRect(origin: .zero, size: size))

        for annotation in annotations {
            if let pf = annotation as? PixelateFilter {
                pf.backgroundImage = bgImage
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

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        switch currentTool {
        case .select:
            handleSelectMouseDown(point: point)
        case .rectangle, .ellipse, .line, .arrow, .text, .speechBubble, .stepLabel, .pixelate, .highlight:
            handleCreateMouseDown(point: point)
        case .crop:
            handleCreateMouseDown(point: point)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if isCreatingAnnotation {
            handleCreateMouseDragged(point: point)
        } else if let annotation = selectedAnnotation {
            if let handle = activeHandle {
                annotation.bounds = handle.resize(bounds: dragOldBounds, to: point)
                needsDisplay = true
            } else {
                let dx = point.x - dragStart.x
                let dy = point.y - dragStart.y
                annotation.bounds = dragOldBounds.offsetBy(dx: dx, dy: dy)
                needsDisplay = true
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if isCreatingAnnotation {
            handleCreateMouseUp(point: point)
        } else if let annotation = selectedAnnotation {
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
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: - Select Tool

    private func handleSelectMouseDown(point: CGPoint) {
        // Check if clicking on a handle of the selected annotation
        if let sel = selectedAnnotation, let handle = sel.handleHitTest(point: point) {
            activeHandle = handle
            dragStart = point
            dragOldBounds = sel.bounds
            dragOldStyle = sel.style
            return
        }

        // Check annotations in reverse order (top-most first)
        for annotation in annotations.reversed() {
            if annotation.hitTest(point: point) {
                selectAnnotation(annotation)
                dragStart = point
                dragOldBounds = annotation.bounds
                dragOldStyle = annotation.style
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
        isCreatingAnnotation = true
        creationStartPoint = point
        let bounds = CGRect(origin: point, size: .zero)

        let annotation: Annotation
        switch currentTool {
        case .rectangle:
            annotation = RectangleAnnotation(bounds: bounds, style: currentStyle)
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
            let bubble = SpeechBubbleAnnotation(bounds: CGRect(origin: point, size: CGSize(width: 150, height: 60)), style: currentStyle)
            annotation = bubble
        case .stepLabel:
            annotation = StepLabelAnnotation(center: point, style: currentStyle)
        case .pixelate:
            let pf = PixelateFilter(bounds: bounds)
            pf.backgroundImage = backgroundImage
            annotation = pf
        case .highlight:
            annotation = HighlightFilter(bounds: bounds)
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
        annotation.bounds = CGRect(
            x: min(creationStartPoint.x, point.x),
            y: min(creationStartPoint.y, point.y),
            width: abs(point.x - creationStartPoint.x),
            height: abs(point.y - creationStartPoint.y)
        )

        // Track direction for line-based annotations (bounds normalization loses this info)
        let direction = DiagonalDirection.from(start: creationStartPoint, end: point)
        if let line = annotation as? LineAnnotation {
            line.direction = direction
        } else if let arrow = annotation as? ArrowAnnotation {
            arrow.direction = direction
        }

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

        // Switch back to select after creation
        currentTool = .select
    }
}
