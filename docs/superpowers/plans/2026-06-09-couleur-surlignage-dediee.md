# Couleur de fond dédiée pour le surlignage — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Donner à l'outil surlignage sa propre couleur de fond gérée et persistée (jaune par défaut), distincte de la couleur « Fond » partagée par les autres outils.

**Architecture:** On ajoute une préférence `defaultHighlightColor`. À chaque changement d'outil, `CanvasView.currentStyle.fillColor` est ré-amorcé depuis la bonne préférence (surlignage vs fond partagé). Les modifications du sélecteur « Fond » sont persistées dans la préférence correspondant à l'outil actif. Le repli jaune codé en dur est remplacé par cette préférence gérée.

**Tech Stack:** Swift 6, AppKit, XCTest, Swift Package Manager (`swift test`).

---

## Structure des fichiers

- Modifier : `Sources/GreenshotMac/App/Preferences.swift` — nouvelle propriété `defaultHighlightColor` + clé.
- Modifier : `Sources/GreenshotMac/Editor/EditorWindowController.swift` — persistance ciblée (`fillColorChanged`, `noFillToggled`) et amorçage au changement d'outil (`canvasView(_:didChangeCurrentTool:)`).
- Modifier : `Sources/GreenshotMac/Editor/CanvasView.swift` — remplacer le jaune codé en dur par `defaultHighlightColor`.
- Test : `Tests/GreenshotMacTests/HighlightColorTests.swift` — nouveau fichier de tests.

Commande de test : `swift test --filter HighlightColorTests`

---

## Task 1 : Préférence `defaultHighlightColor`

**Files:**
- Modify: `Sources/GreenshotMac/App/Preferences.swift` (clé dans `enum Keys` ~ligne 13 ; propriété après `defaultFillColor` ~ligne 78)
- Test: `Tests/GreenshotMacTests/HighlightColorTests.swift` (créer)

- [ ] **Step 1 : Écrire le test qui échoue**

Créer `Tests/GreenshotMacTests/HighlightColorTests.swift` :

```swift
import XCTest
import AppKit
@testable import GreenshotMac

@MainActor
final class HighlightColorTests: XCTestCase {

    // MARK: - Task 1: Preferences.defaultHighlightColor

    func testDefaultHighlightColorDefaultsToTranslucentYellow() {
        let prefs = Preferences.shared
        let original = prefs.defaultHighlightColor
        // Reset to absent state by writing nil-equivalent: store then clear key path.
        UserDefaults.standard.removeObject(forKey: "defaultHighlightColorData")

        let expected = NSColor.yellow.withAlphaComponent(0.4)
        let actual = prefs.defaultHighlightColor
        XCTAssertEqual(actual.alphaComponent, expected.alphaComponent, accuracy: 0.01)
        let rgbActual = actual.usingColorSpace(.sRGB)
        let rgbExpected = expected.usingColorSpace(.sRGB)
        XCTAssertEqual(rgbActual?.redComponent ?? -1, rgbExpected?.redComponent ?? -2, accuracy: 0.01)
        XCTAssertEqual(rgbActual?.greenComponent ?? -1, rgbExpected?.greenComponent ?? -2, accuracy: 0.01)
        XCTAssertEqual(rgbActual?.blueComponent ?? -1, rgbExpected?.blueComponent ?? -2, accuracy: 0.01)

        prefs.defaultHighlightColor = original
    }

    func testDefaultHighlightColorPersists() {
        let prefs = Preferences.shared
        let original = prefs.defaultHighlightColor

        prefs.defaultHighlightColor = .magenta
        XCTAssertEqual(prefs.defaultHighlightColor, .magenta)

        prefs.defaultHighlightColor = original
    }
}
```

- [ ] **Step 2 : Lancer le test pour vérifier qu'il échoue**

Run: `swift test --filter HighlightColorTests`
Expected: ÉCHEC de compilation — `value of type 'Preferences' has no member 'defaultHighlightColor'`.

- [ ] **Step 3 : Implémenter la préférence**

Dans `Sources/GreenshotMac/App/Preferences.swift`, ajouter la clé dans `enum Keys` (juste après `defaultFillColorData` à la ligne 13) :

```swift
        static let defaultHighlightColorData = "defaultHighlightColorData"
```

Puis ajouter la propriété juste après le bloc `defaultFillColor` (après la ligne 78) :

```swift
    var defaultHighlightColor: NSColor {
        get {
            guard let data = defaults.data(forKey: Keys.defaultHighlightColorData),
                  let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
            else { return NSColor.yellow.withAlphaComponent(0.4) }
            return color
        }
        set {
            let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true)
            defaults.set(data, forKey: Keys.defaultHighlightColorData)
        }
    }
```

- [ ] **Step 4 : Lancer le test pour vérifier qu'il passe**

Run: `swift test --filter HighlightColorTests`
Expected: PASS (2 tests).

- [ ] **Step 5 : Commit**

```bash
git add Sources/GreenshotMac/App/Preferences.swift Tests/GreenshotMacTests/HighlightColorTests.swift
git commit -m "feat: add Preferences.defaultHighlightColor (default translucent yellow)"
```

---

## Task 2 : Persistance ciblée selon l'outil actif

Quand l'outil actif est `highlight`, `fillColorChanged` et `noFillToggled` persistent dans `defaultHighlightColor` ; sinon dans `defaultFillColor` (comportement actuel).

**Files:**
- Modify: `Sources/GreenshotMac/Editor/EditorWindowController.swift:476-482` (`fillColorChanged`) et `:504-519` (`noFillToggled`)
- Test: `Tests/GreenshotMacTests/HighlightColorTests.swift`

- [ ] **Step 1 : Écrire les tests qui échouent**

Ajouter dans `HighlightColorTests` :

```swift
    // MARK: - Task 2: Persistence routed by active tool

    func testFillColorChangedPersistsToHighlightWhenHighlightActive() {
        let controller = makeEditorController()
        let prefs = Preferences.shared
        let originalFill = prefs.defaultFillColor
        let originalHighlight = prefs.defaultHighlightColor

        controller.canvasView.currentTool = .highlight
        controller.fillColorWell.color = .magenta
        controller.fillColorChanged(controller.fillColorWell)

        XCTAssertEqual(prefs.defaultHighlightColor, .magenta,
            "Highlight tool active -> change must persist to defaultHighlightColor")
        XCTAssertEqual(prefs.defaultFillColor, originalFill,
            "Shared fill color must not change while highlight is active")

        prefs.defaultFillColor = originalFill
        prefs.defaultHighlightColor = originalHighlight
    }

    func testFillColorChangedPersistsToFillWhenRectangleActive() {
        let controller = makeEditorController()
        let prefs = Preferences.shared
        let originalFill = prefs.defaultFillColor
        let originalHighlight = prefs.defaultHighlightColor

        controller.canvasView.currentTool = .rectangle
        controller.fillColorWell.color = .cyan
        controller.fillColorChanged(controller.fillColorWell)

        XCTAssertEqual(prefs.defaultFillColor, .cyan,
            "Non-highlight tool -> change must persist to defaultFillColor")
        XCTAssertEqual(prefs.defaultHighlightColor, originalHighlight,
            "Highlight color must not change for non-highlight tools")

        prefs.defaultFillColor = originalFill
        prefs.defaultHighlightColor = originalHighlight
    }
```

- [ ] **Step 2 : Lancer les tests pour vérifier qu'ils échouent**

Run: `swift test --filter HighlightColorTests`
Expected: ÉCHEC — `testFillColorChangedPersistsToHighlightWhenHighlightActive` échoue car la valeur est écrite dans `defaultFillColor` au lieu de `defaultHighlightColor`.

- [ ] **Step 3 : Implémenter le routage de persistance**

Dans `EditorWindowController.swift`, remplacer la ligne 481 (dans `fillColorChanged`) :

```swift
        Preferences.shared.defaultFillColor = sender.color
```

par :

```swift
        if canvasView.currentTool == .highlight {
            Preferences.shared.defaultHighlightColor = sender.color
        } else {
            Preferences.shared.defaultFillColor = sender.color
        }
```

Puis remplacer la ligne 518 (dans `noFillToggled`) :

```swift
        Preferences.shared.defaultFillColor = canvasView.currentStyle.fillColor
```

par :

```swift
        if canvasView.currentTool == .highlight {
            Preferences.shared.defaultHighlightColor = canvasView.currentStyle.fillColor
        } else {
            Preferences.shared.defaultFillColor = canvasView.currentStyle.fillColor
        }
```

- [ ] **Step 4 : Lancer les tests pour vérifier qu'ils passent**

Run: `swift test --filter HighlightColorTests`
Expected: PASS.

- [ ] **Step 5 : Commit**

```bash
git add Sources/GreenshotMac/Editor/EditorWindowController.swift Tests/GreenshotMacTests/HighlightColorTests.swift
git commit -m "feat: route fill-color persistence to highlight pref when highlight tool active"
```

---

## Task 3 : Amorçage de `currentStyle.fillColor` au changement d'outil

À l'entrée dans `highlight`, `currentStyle.fillColor` est amorcé depuis `defaultHighlightColor`. À l'entrée dans un autre outil supportant le fond (hors `stepLabel`), il est amorcé depuis `defaultFillColor`.

**Files:**
- Modify: `Sources/GreenshotMac/Editor/EditorWindowController.swift:1097-1110` (branche `else` de `canvasView(_:didChangeCurrentTool:)`)
- Test: `Tests/GreenshotMacTests/HighlightColorTests.swift`

- [ ] **Step 1 : Écrire le test qui échoue**

Ajouter dans `HighlightColorTests` :

```swift
    // MARK: - Task 3: Tool-switch seeding of currentStyle.fillColor

    func testSwitchingToHighlightSeedsHighlightColor() {
        let controller = makeEditorController()
        let prefs = Preferences.shared
        let originalFill = prefs.defaultFillColor
        let originalHighlight = prefs.defaultHighlightColor

        prefs.defaultFillColor = .white
        prefs.defaultHighlightColor = .yellow

        controller.canvasView.currentTool = .rectangle
        XCTAssertEqual(controller.canvasView.currentStyle.fillColor, .white,
            "Rectangle should seed the shared fill color")

        controller.canvasView.currentTool = .highlight
        XCTAssertEqual(controller.canvasView.currentStyle.fillColor, .yellow,
            "Highlight should seed its dedicated color, not the shared white")

        controller.canvasView.currentTool = .rectangle
        XCTAssertEqual(controller.canvasView.currentStyle.fillColor, .white,
            "Returning to rectangle should restore the shared fill color")

        prefs.defaultFillColor = originalFill
        prefs.defaultHighlightColor = originalHighlight
    }
```

- [ ] **Step 2 : Lancer le test pour vérifier qu'il échoue**

Run: `swift test --filter HighlightColorTests`
Expected: ÉCHEC — après bascule vers `.highlight`, `currentStyle.fillColor` vaut encore `.white` au lieu de `.yellow`.

- [ ] **Step 3 : Implémenter l'amorçage**

Dans `EditorWindowController.swift`, dans `canvasView(_:didChangeCurrentTool:)`, la branche `else` (pas d'annotation sélectionnée) est actuellement :

```swift
        } else {
            if tool == .stepLabel {
                var displayStyle = canvas.currentStyle
                if displayStyle.fillColor == .clear {
                    displayStyle.fillColor = StepLabelAnnotation.defaultStyle.fillColor
                }
                if displayStyle.strokeColor == AnnotationStyle().strokeColor {
                    displayStyle.strokeColor = StepLabelAnnotation.defaultStyle.strokeColor
                }
                updateStyleControls(for: tool, style: displayStyle)
            } else {
                updateStyleControls(for: tool, style: canvas.currentStyle)
            }
        }
```

La remplacer par (ajout du bloc d'amorçage en tête de la branche `else`) :

```swift
        } else {
            // Seed the active fill color from the right persisted default so the
            // highlighter keeps its own colour, distinct from the shared "Fond".
            if tool == .highlight {
                canvas.currentStyle.fillColor = Preferences.shared.defaultHighlightColor
            } else if tool.supportsFillColor && tool != .stepLabel {
                canvas.currentStyle.fillColor = Preferences.shared.defaultFillColor
            }

            if tool == .stepLabel {
                var displayStyle = canvas.currentStyle
                if displayStyle.fillColor == .clear {
                    displayStyle.fillColor = StepLabelAnnotation.defaultStyle.fillColor
                }
                if displayStyle.strokeColor == AnnotationStyle().strokeColor {
                    displayStyle.strokeColor = StepLabelAnnotation.defaultStyle.strokeColor
                }
                updateStyleControls(for: tool, style: displayStyle)
            } else {
                updateStyleControls(for: tool, style: canvas.currentStyle)
            }
        }
```

- [ ] **Step 4 : Lancer le test pour vérifier qu'il passe**

Run: `swift test --filter HighlightColorTests`
Expected: PASS.

- [ ] **Step 5 : Commit**

```bash
git add Sources/GreenshotMac/Editor/EditorWindowController.swift Tests/GreenshotMacTests/HighlightColorTests.swift
git commit -m "feat: seed active fill color from per-tool preference on tool switch"
```

---

## Task 4 : Remplacer le jaune codé en dur à la création

Le repli jaune codé en dur dans la création d'un `HighlightFilter` (`CanvasView.handleCreateMouseDown`) est remplacé par `Preferences.shared.defaultHighlightColor`, conservant un filet de sécurité si `fillColor` est `.clear`.

**Pourquoi pas de nouveau test unitaire ici :** la création par drag passe par `handleCreateMouseDown` (méthode `private`, pilotée par des `NSEvent`). Aucun test du codebase ne pilote ce chemin — la convention est d'ajouter les annotations via `addAnnotation(_:)`. Le comportement observable pour l'utilisateur (le fond blanc d'un autre outil ne fuit pas dans le surligneur) est **déjà** prouvé par `testSwitchingToHighlightSeedsHighlightColor` (Task 3), puisque la création lit `currentStyle.fillColor` que la Task 3 garantit déjà égal à `defaultHighlightColor`. La modification ci-dessous n'affecte plus que le filet de sécurité `.clear` (création sans bascule d'outil préalable, cas qui ne survient pas via l'UI) ; elle est couverte par la non-régression (Task 5) et la vérification manuelle.

**Files:**
- Modify: `Sources/GreenshotMac/Editor/CanvasView.swift:749-755`

- [ ] **Step 1 : Remplacer le jaune codé en dur**

Dans `CanvasView.swift`, remplacer le bloc lignes 749-755 :

```swift
        case .highlight:
            var highlightStyle = currentStyle
            // Default to yellow highlight if fill color is clear
            if highlightStyle.fillColor == .clear {
                highlightStyle.fillColor = NSColor.yellow.withAlphaComponent(0.4)
            }
            annotation = HighlightFilter(bounds: bounds, style: highlightStyle)
```

par :

```swift
        case .highlight:
            var highlightStyle = currentStyle
            // Fall back to the managed highlight colour if no fill is set.
            if highlightStyle.fillColor == .clear {
                highlightStyle.fillColor = Preferences.shared.defaultHighlightColor
            }
            annotation = HighlightFilter(bounds: bounds, style: highlightStyle)
```

> Note : grâce à la Task 3, lorsque l'outil `highlight` est actif, `currentStyle.fillColor` porte déjà `defaultHighlightColor`. Le bloc `if .clear` ne reste qu'un filet de sécurité (création sans bascule d'outil préalable).

- [ ] **Step 2 : Vérifier que le projet compile et que la suite ciblée passe toujours**

Run: `swift test --filter HighlightColorTests`
Expected: PASS (aucun nouveau test, mais la compilation valide le changement).

- [ ] **Step 3 : Commit**

```bash
git add Sources/GreenshotMac/Editor/CanvasView.swift
git commit -m "feat: use managed highlight color instead of hardcoded yellow on creation"
```

---

## Task 5 : Régression — la suite complète passe

**Files:** aucun changement de code attendu.

- [ ] **Step 1 : Lancer toute la suite de tests**

Run: `swift test`
Expected: PASS (toute la suite, y compris `StyleActionTests`, `StyleBarVisibilityTests`, `HighlightColorTests`).

- [ ] **Step 2 : Si des tests existants échouent**

Investiguer via la skill `superpowers:systematic-debugging`. Un échec probable : un test qui supposait l'ancien repli jaune codé en dur. Corriger le test pour refléter le nouveau comportement (couleur gérée) uniquement si le test encode l'ancien comportement codé en dur ; sinon corriger le code.

- [ ] **Step 3 : Commit (si correctifs nécessaires)**

```bash
git add -A
git commit -m "test: align existing tests with managed highlight color"
```

---

## Vérification manuelle (après implémentation)

Construire et lancer l'app (skill `deploy` ou `run`), puis :

1. Avec l'outil rectangle, mettre un fond **blanc**. Basculer vers le **surlignage** → le picker « Fond » doit afficher le **jaune** (pas blanc), et tracer un surlignage jaune.
2. Changer la couleur du surligneur (p.ex. vert), revenir au **rectangle** → le fond doit redevenir **blanc** (la couleur du surligneur n'a pas pollué le fond partagé).
3. Quitter et relancer l'éditeur → le surligneur conserve la dernière couleur choisie (`defaultHighlightColor` persistée).
