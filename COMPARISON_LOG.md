# Journal de comparaison GreenshotMac vs Greenshot Windows

## Annotations à comparer

- [x] Arrow
- [ ] Text
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
