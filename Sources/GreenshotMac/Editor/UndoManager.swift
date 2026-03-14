import AppKit

enum AnnotationAction {
    case add(Annotation)
    case remove(Annotation, Int) // annotation + index
    case modify(Annotation, CGRect, AnnotationStyle) // annotation + old bounds + old style
    case reorder(Annotation, Int, Int) // annotation + old index + new index
}

@MainActor
final class AnnotationUndoManager {
    private let undoManager = Foundation.UndoManager()
    private weak var canvas: CanvasView?

    init(canvas: CanvasView) {
        self.canvas = canvas
    }

    var nsUndoManager: Foundation.UndoManager { undoManager }

    func recordAdd(_ annotation: Annotation) {
        undoManager.registerUndo(withTarget: self) { [weak self] target in
            self?.canvas?.removeAnnotation(annotation, isUndoAction: true)
            target.undoManager.registerUndo(withTarget: target) { target2 in
                self?.canvas?.addAnnotation(annotation, isUndoAction: true)
            }
        }
        undoManager.setActionName("Ajouter une annotation")
    }

    func recordRemove(_ annotation: Annotation, at index: Int) {
        undoManager.registerUndo(withTarget: self) { [weak self] target in
            self?.canvas?.insertAnnotation(annotation, at: index, isUndoAction: true)
            target.undoManager.registerUndo(withTarget: target) { target2 in
                self?.canvas?.removeAnnotation(annotation, isUndoAction: true)
            }
        }
        undoManager.setActionName("Supprimer une annotation")
    }

    func recordReorder(_ annotation: Annotation, from oldIndex: Int, to newIndex: Int) {
        undoManager.registerUndo(withTarget: self) { [weak self] target in
            self?.canvas?.moveAnnotation(annotation, from: newIndex, to: oldIndex)
            target.undoManager.registerUndo(withTarget: target) { target2 in
                self?.canvas?.moveAnnotation(annotation, from: oldIndex, to: newIndex)
            }
        }
        undoManager.setActionName("Réordonner une annotation")
    }

    func recordPropertyChange(_ annotation: Annotation, undo undoBlock: @escaping @MainActor () -> Void, redo redoBlock: @escaping @MainActor () -> Void) {
        undoManager.registerUndo(withTarget: self) { [weak self] target in
            MainActor.assumeIsolated {
                undoBlock()
                self?.canvas?.needsDisplay = true
                target.undoManager.registerUndo(withTarget: target) { [weak self] target2 in
                    MainActor.assumeIsolated {
                        redoBlock()
                        self?.canvas?.needsDisplay = true
                    }
                }
            }
        }
        undoManager.setActionName("Modifier une annotation")
    }

    func recordModify(_ annotation: Annotation, oldBounds: CGRect, oldStyle: AnnotationStyle) {
        let newBounds = annotation.bounds
        let newStyle = annotation.style
        undoManager.registerUndo(withTarget: self) { [weak self] target in
            annotation.bounds = oldBounds
            annotation.style = oldStyle
            self?.canvas?.needsDisplay = true
            target.undoManager.registerUndo(withTarget: target) { target2 in
                annotation.bounds = newBounds
                annotation.style = newStyle
                self?.canvas?.needsDisplay = true
            }
        }
        undoManager.setActionName("Modifier une annotation")
    }
}
