# Journal de comparaison GreenshotMac vs Greenshot Windows

## Annotations à comparer

- [x] Arrow
- [x] Text
- [x] SpeechBubble
- [x] Rectangle
- [x] Ellipse
- [x] Line
- [x] StepLabel
- [x] Pixelate
- [x] Highlight
- [ ] Crop
- [ ] Shadow

---

## Itérations

### Itération 1 — Arrow

**Fichiers C# lus :**
- `Drawing/ArrowContainer.cs` (160 lignes)
- `Drawing/LineContainer.cs` (122 lignes) — classe parent
- `Drawing/DrawableContainer.cs` (687 lignes) — classe de base

**Écarts trouvés :**

| Aspect | Greenshot Windows | GreenshotMac (avant) | Correction |
|--------|------------------|---------------------|------------|
| ArrowHeadCombination | Enum NONE/START/END/BOTH | Toujours END_POINT fixe | Ajout enum + propriété `arrowHeads` |
| Arrowhead sizing | `AdjustableArrowCap(4, 6)` — width=4×strokeWidth, height=6×strokeWidth | `10 + strokeWidth * 2` — formule ad hoc | Dimensions proportionnelles: 4× et 6× strokeWidth |
| Hit test arrowhead | GraphicsPath.IsOutlineVisible() inclut flèche | Distance au segment seulement | Hit test triangle via coordonnées barycentriques |
| Hit test tolerance | +10px sur épaisseur du trait | 6px fixe | `max(6, strokeWidth + 4)` |
| Shadow rendering | 5 couches progressives alpha 100→20 | NSShadow unique | Conservé tel quel (idiome macOS) |

**Corrections apportées :**
- Ajout `ArrowHeadCombination` enum dans `AnnotationProtocol.swift`
- Refonte `ArrowAnnotation.swift` : arrowHeads property, sizing proportionnel, hit test triangle
- Méthode `arrowheadPoints(tip:towards:)` pour calcul géométrique réutilisable
- Hit test : segment + triangles des pointes actives

**Tests ajoutés/modifiés :**
- `testDefaultArrowHeadIsEndPoint` — vérifie le défaut .endPoint
- `testArrowHeadCombinationNone/StartPoint/Both` — toutes les combinaisons
- `testCopyPreservesArrowHeadCombination` — persistance lors de copy()
- `testArrowheadPointsProportionalToStrokeWidth` — dimensions 4×/6× strokeWidth
- `testArrowheadScalesWithStrokeWidth` — scaling avec strokeWidth=5
- `testHitTestOnEndArrowhead` — clic sur le triangle de la pointe
- `testHitTestOnStartArrowheadWhenBoth` — clic sur pointe de départ
- `testHitTestMissesArrowheadWhenNone` — pas de détection quand .none
- `testHitTestToleranceScalesWithStrokeWidth` — tolérance dynamique

**Résultat des tests :** ✅ 253 tests, 0 failures

### Itération 2 — Text

**Fichiers C# lus :**
- `Drawing/TextContainer.cs` — classe principale
- `Drawing/RectangleContainer.cs` — classe parent

**Écarts trouvés :**

| Aspect | Greenshot Windows | GreenshotMac (avant) | Correction |
|--------|------------------|---------------------|------------|
| Bold/Italic | `FONT_BOLD`, `FONT_ITALIC` fields | Pas de support | Ajout `fontBold`/`fontItalic` dans AnnotationStyle |
| Font resolution | CreateFont() avec fallback par style disponible | `NSFont(name:size:)` simple | `resolveFont()` via NSFontManager.convert toHaveTrait |
| Horizontal alignment | StringAlignment Near/Center/Far, default Center | Aucun | Ajout `textHorizontalAlignment` (.left/.center/.right) |
| Vertical alignment | StringAlignment Near/Center/Far, default Center | Aucun | Ajout `textVerticalAlignment` (.top/.center/.bottom) |
| Default font size | 11f (pixels) | 14.0 | Conservé 14.0 (meilleur rendu Retina) |
| Inline editing | TextBox overlay, double-click, ESC/Enter | Absent | À FAIRE (trop complexe pour une itération) |
| FitToText | Auto-resize bounds to text content | Absent | À FAIRE |

**Corrections apportées :**
- Ajout enums `TextHorizontalAlignment` et `TextVerticalAlignment` dans AnnotationProtocol.swift
- Ajout `fontBold`, `fontItalic`, `textHorizontalAlignment`, `textVerticalAlignment` dans AnnotationStyle
- Nouvelle méthode `resolveFont()` dans TextAnnotation avec NSFontManager trait conversion
- Rendu vertical alignment via CTFramesetterSuggestFrameSizeWithConstraints pour mesurer la hauteur
- Horizontal alignment via NSParagraphStyle.alignment dans les attributs CoreText

**Tests ajoutés :**
- `testDefaultStyleHasNoBoldOrItalic`
- `testResolveFontWithBold` / `testResolveFontWithItalic` / `testResolveFontWithBoldAndItalic`
- `testResolveFontFallsBackToSystemFont`
- `testDefaultAlignmentIsCenterCenter`
- `testHorizontalAlignmentLeft` / `testHorizontalAlignmentRight`
- `testVerticalAlignmentTop` / `testVerticalAlignmentBottom`
- `testCopyPreservesAlignmentAndFontTraits`

**Résultat des tests :** ✅ 264 tests, 0 failures

### Itération 3 — SpeechBubble

**Fichiers C# lus :**
- `Drawing/SpeechbubbleContainer.cs` — classe principale

**Écarts trouvés :**

| Aspect | Greenshot Windows | GreenshotMac (avant) | Correction |
|--------|------------------|---------------------|------------|
| Corner radius | Adaptatif: min(30, smallerSide/2 - lineThickness) | Fixe 8px | Adaptatif via computed property |
| Tail width | (w+h)/20, capped to half dims | Fixed min(20, w*0.3) | Formule Windows + minimum 4px |
| Default stroke color | Blue | Red (hérité) | .systemBlue |
| Default fill color | White | Clear (hérité) | .white |
| Default font bold | true | false (hérité) | true |
| Default font size | 20f | 14.0 (hérité) | 20.0 |
| Default shadow | false | enabled (hérité) | .none |
| Text rendering | Bold/italic/alignment via TextContainer | Pas de support | Intégré via resolveFont() + alignment |
| Tail draggable | TargetAdorner + drag | Position fixe | À FAIRE |
| Clipping regions | Exclude tail/bubble for clean overlap | Pas de clipping | Différence visuelle mineure |

**Corrections apportées :**
- Refonte SpeechBubbleAnnotation avec defaultStyle statique (blue/white/bold/20pt/no-shadow)
- Corner radius adaptatif via computed property
- Tail width via formule Windows (w+h)/20 avec caps
- Texte avec bold/italic/alignment intégré (même resolveFont() que TextAnnotation)
- Init accepte style optionnel (nil = defaultStyle)

**Tests ajoutés :**
- `testDefaultStyleIsBlueStroke` / `testDefaultStyleIsWhiteFill` / `testDefaultStyleIsBold`
- `testDefaultStyleFontSize20` / `testDefaultStyleNoShadow`
- `testCornerRadiusAdaptiveToSmallSide` / `testCornerRadiusCapsAt30`
- `testCornerRadiusReducesForSmallBubble` / `testCornerRadiusZeroForTinyBubble`
- `testTailWidthFormula` / `testTailWidthCappedToHalfSmallDimension` / `testTailWidthLargeBubble`
- `testCustomStyleOverridesDefaults`

**Résultat des tests :** ✅ 277 tests, 0 failures

### Itération 4 — Rectangle + Ellipse

**Fichiers C# lus :**
- `Drawing/RectangleContainer.cs` (169 lignes)
- `Drawing/EllipseContainer.cs` (178 lignes)

**Écarts trouvés :**

| Aspect | Greenshot Windows | GreenshotMac (avant) | Correction |
|--------|------------------|---------------------|------------|
| Rectangle | Aligné | Aligné | Aucune correction nécessaire |
| Ellipse hit test | Equation ellipse x²/a² + y²/b² | bounds.insetBy.contains() rectangulaire | Équation ellipse implémentée |
| Ellipse unfilled hit | Outline visible via GraphicsPath | Pas de distinction filled/unfilled | Ring (outer-inner ellipse) pour unfilled |
| Hit test tolerance | +10px sur line thickness | +4px sur bounds | max(4, strokeWidth + 4) |

**Corrections apportées :**
- EllipseAnnotation: override hitTest avec équation de l'ellipse
- Unfilled: teste que le point est entre l'ellipse intérieure et extérieure (anneau)
- Filled: teste que le point est dans l'ellipse élargie par la tolérance
- Rectangle: déjà aligné, pas de modification

**Tests ajoutés/modifiés :**
- `testHitTestOnOutlineHits` — point sur le contour
- `testHitTestCenterOfUnfilledMisses` — centre de l'ellipse non remplie
- `testHitTestAtCornerOfBoundsForUnfilledEllipse` — coin du rect englobant
- `testHitTestOnEllipseOutline` — contour exact
- `testHitTestInsideUnfilledEllipseMisses` — centre d'une grande ellipse non remplie
- `testHitTestInsideFilledEllipseHits` — centre d'une ellipse remplie
- `testHitTestFilledEllipseCornerMisses` — coin du rect rempli
- `testHitTestNarrowEllipse` — ellipse étroite

**Résultat des tests :** ✅ 284 tests, 0 failures

### Itération 5 — Line + StepLabel

**Fichiers C# lus :**
- `Drawing/LineContainer.cs` (122 lignes)
- `Drawing/StepLabelContainer.cs`

**Écarts trouvés :**

| Aspect | Greenshot Windows | GreenshotMac (avant) | Correction |
|--------|------------------|---------------------|------------|
| Line hit test tolerance | lineThickness + 5 | 6px fixe | max(6, strokeWidth + 5) |
| Line dash pattern | Aucun | Aucun | Aligné |
| StepLabel fill color | DarkRed | systemRed (quand clear) | DarkRed par défaut |
| StepLabel shadow | false | enabled par défaut | .none |
| StepLabel font sizing | Dynamique: scaled to fit circle | Fixe: style.fontSize | autoScaledFontSize() |
| StepLabel counter | Per-surface, recalculated | Static, sequential | Conservé (acceptable) |

**Corrections apportées :**
- LineAnnotation: hit test tolerance = max(6, strokeWidth + 5) au lieu de 6px fixe
- StepLabelAnnotation: defaultStyle avec DarkRed, white, no shadow
- StepLabelAnnotation: autoScaledFontSize() calcule la taille de police pour tenir dans le cercle
- Init accepte style optionnel (nil = defaultStyle)

**Tests modifiés :**
- `testDefaultFillColorIsRedWhenClear` → `testDefaultFillColorIsDarkRed`

**Résultat des tests :** ✅ 284 tests, 0 failures

### Itération 6 — Pixelate + Highlight

**Fichiers C# lus :**
- `Drawing/Filters/PixelizationFilter.cs`
- `Drawing/Filters/HighlightFilter.cs`
- `Drawing/Filters/AbstractFilter.cs`

**Écarts trouvés :**

| Aspect | Greenshot Windows | GreenshotMac | Statut |
|--------|------------------|--------------|--------|
| Pixelate algorithm | Manual pixel averaging per block | CIPixellate Core Image filter | Aligné (même résultat) |
| Pixelate default size | 5px | 5px | Aligné |
| Pixelate edge handling | Adapts block size to bounds | Adapts block size to bounds | Aligné |
| Highlight blend | Math.Min per RGB component (darkening) | Alpha overlay semi-transparent | Acceptable adaptation macOS |
| Highlight default color | Yellow | Yellow at 40% alpha | Aligné conceptuellement |
| Highlight shadow | false | false (toujours .none) | Aligné |

**Corrections apportées :**
- Aucune modification de code — les deux filtres sont bien alignés
- Mise à jour SPEC.md §5.2 pour documenter la différence de blend mode

**Résultat des tests :** ✅ 284 tests, 0 failures
