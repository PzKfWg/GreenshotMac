import XCTest
import AppKit
@testable import GreenshotMac

@MainActor
func makeEditorController(width: CGFloat = 400, height: CGFloat = 300) -> EditorWindowController {
    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    NSColor.white.setFill()
    NSRect(origin: .zero, size: image.size).fill()
    image.unlockFocus()
    let controller = EditorWindowController(image: image, sourceURL: nil)
    _ = controller.window  // force windowDidLoad
    return controller
}

@MainActor
func makeCanvasForController(_ controller: EditorWindowController) -> CanvasView {
    return controller.canvasView
}
