# Couleur de fond dédiée pour l'outil surlignage

**Date :** 2026-06-09
**Statut :** Design approuvé

## Problème

L'outil surlignage (`highlight`) partage la couleur « Fond » (`AnnotationStyle.fillColor`)
avec tous les autres outils via l'état unique `CanvasView.currentStyle.fillColor`,
persisté dans `Preferences.defaultFillColor`.

Le jaune translucide du surligneur n'est qu'un *repli* appliqué uniquement quand la
couleur de fond vaut exactement `.clear` :

- [HighlightFilter.swift:19](../../../Sources/GreenshotMac/Editor/Filters/HighlightFilter.swift#L19) — `NSColor.yellow.withAlphaComponent(0.4)`
- [CanvasView.swift:749](../../../Sources/GreenshotMac/Editor/CanvasView.swift#L749) — repli si `fillColor == .clear`

En pratique, les autres outils utilisent souvent du blanc ou du transparent. Dès qu'un
autre outil fixe un fond blanc (opaque, donc différent de `.clear`), le surlignage hérite
de ce blanc au lieu de son jaune. Le jaune n'est jamais conservé de façon distincte.

## Objectif

Le surlignage possède sa **propre couleur de fond gérée**, persistée séparément et
distincte de la couleur « Fond » partagée par les autres outils. Le sélecteur « Fond »
reste fonctionnel pour modifier la teinte du surligneur quand cet outil est actif.

## Approche retenue (A)

Une couleur de surlignage persistée séparément, qui réutilise le « tuyau » existant
(`currentStyle.fillColor`) afin de minimiser les points de modification.

### Composants

1. **Préférence dédiée** — `Preferences.defaultHighlightColor`
   - Nouvelle clé `defaultHighlightColorData` dans `Preferences.Keys`.
   - Sérialisation `NSKeyedArchiver` / `NSKeyedUnarchiver`, comme `defaultFillColor`.
   - Valeur par défaut : `NSColor.yellow.withAlphaComponent(0.4)`.

2. **Amorçage au changement d'outil** — `EditorWindowController.canvasView(_:didChangeCurrentTool:)`
   - À l'entrée dans l'outil `highlight` : `currentStyle.fillColor = prefs.defaultHighlightColor`.
   - À l'entrée dans un autre outil supportant le fond (hors `stepLabel`, qui garde son
     comportement actuel) : `currentStyle.fillColor = prefs.defaultFillColor`.
   - Le picker « Fond » affiche alors la bonne couleur via le `displayStyle` passé à
     `updateStyleControls`.

3. **Persistance ciblée** — `fillColorChanged(_:)` et `noFillToggled(_:)`
   - Si l'outil actif est `highlight` → persister dans `Preferences.defaultHighlightColor`.
   - Sinon → persister dans `Preferences.defaultFillColor` (comportement actuel).
   - Dans les deux cas, `currentStyle.fillColor` et l'annotation sélectionnée sont mis à
     jour comme aujourd'hui (`applyStyleToSelectedAnnotation` inchangé).

4. **Nettoyage des replis jaunes codés en dur**
   - Retirer le fallback `if highlightStyle.fillColor == .clear { … yellow }` à
     [CanvasView.swift:749](../../../Sources/GreenshotMac/Editor/CanvasView.swift#L749) :
     `currentStyle.fillColor` porte désormais déjà la bonne couleur de surlignage.
   - Conserver le défaut interne de `HighlightFilter` (HighlightFilter.swift:19) comme
     filet de sécurité pour les `HighlightFilter` créés sans style.

### Flux résultant

- Outil rectangle, fond blanc → `defaultFillColor` = blanc.
- Bascule vers surlignage → `currentStyle.fillColor` initialisé à `defaultHighlightColor`
  (jaune). Aucun conflit : le blanc reste dans `defaultFillColor`.
- L'utilisateur change la teinte du surligneur via « Fond » → persiste dans
  `defaultHighlightColor` uniquement.
- Retour au rectangle → `currentStyle.fillColor` restauré à `defaultFillColor` (blanc).

Le jaune (ou la teinte choisie) du surligneur ne pollue jamais le fond des autres outils,
et inversement.

## Hors périmètre

- Pas de couleur mémorisée par outil de façon générale (option C écartée).
- Pas de changement au mode de fusion `multiply` ni au slider d'opacité du surligneur.
- `stepLabel` conserve son comportement actuel (repli sur `defaultStyle` quand `.clear`).

## Tests

- Vérifier qu'après avoir mis un fond blanc sur un rectangle puis basculé vers le
  surlignage, le surligneur affiche/applique le jaune (et non le blanc).
- Vérifier que changer la couleur du surligneur ne modifie pas `defaultFillColor`
  (les autres outils gardent leur fond), et inversement.
- Vérifier la persistance : `defaultHighlightColor` est rechargée correctement au
  redémarrage de l'éditeur.
