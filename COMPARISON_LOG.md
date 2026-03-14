# Journal de comparaison GreenshotMac vs Greenshot Windows

## Annotations à comparer

- [x] Arrow
- [x] Text
- [ ] SpeechBubble
- [ ] Rectangle
- [ ] Ellipse
- [ ] Line
- [ ] StepLabel
- [ ] Pixelate
- [ ] Highlight
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
