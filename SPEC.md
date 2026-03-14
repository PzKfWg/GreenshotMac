# GreenshotMac - Spécification fonctionnelle

## Vue d'ensemble

GreenshotMac est un éditeur d'annotations d'images pour macOS, inspiré de Greenshot pour Windows. L'application ne fait **pas** de capture d'écran : elle s'appuie sur la capture native de macOS (Cmd+Shift+3/4/5) et offre un éditeur pour annoter, filtrer et exporter les images capturées.

Usage personnel uniquement. Pas de distribution App Store, pas de plugins, pas d'exports cloud.

## Architecture

- **Langage :** Swift 6 avec strict concurrency (`@MainActor`)
- **Framework UI :** AppKit (NSView, NSWindow, NSToolbar, NSStatusItem)
- **Build :** Swift Package Manager (`swift build`, `swift test`, `swift run`)
- **Tests :** XCTest

---

## 1. Application shell

### 1.1 Menu bar (NSStatusItem)

L'application vit dans la barre de menu macOS avec une icône (`pencil.and.outline`). Elle n'apparaît pas dans le Dock (`NSApp.setActivationPolicy(.accessory)`).

**Menu contextuel :**

| Item | Raccourci | Comportement |
|------|-----------|-------------|
| Open Image... | Cmd+O | Ouvre un `NSOpenPanel` filtré sur PNG, JPEG, TIFF, BMP. Ouvre l'éditeur avec l'image sélectionnée. |
| Paste from Clipboard | Cmd+V | Lit une image depuis `NSPasteboard.general`. Si une image est présente, ouvre l'éditeur avec. Sinon, ne fait rien (pas d'alerte). |
| Preferences... | Cmd+, | Ouvre la fenêtre de préférences (stub pour l'instant). |
| Quit GreenshotMac | Cmd+Q | Ferme l'application. |

**Cas de test :**
- CT-1.1.1 : Au lancement, l'icône apparaît dans la barre de menu.
- CT-1.1.2 : L'application n'apparaît PAS dans le Dock.
- CT-1.1.3 : Cliquer l'icône affiche le menu avec les 5 items (Open, Paste, separator, Preferences, separator, Quit).
- CT-1.1.4 : "Open Image..." ouvre un NSOpenPanel. Sélectionner un PNG ouvre l'éditeur avec cette image.
- CT-1.1.5 : "Open Image..." avec annulation ne fait rien.
- CT-1.1.6 : "Paste from Clipboard" avec une image dans le clipboard ouvre l'éditeur.
- CT-1.1.7 : "Paste from Clipboard" sans image dans le clipboard ne fait rien (pas de crash, pas d'alerte).
- CT-1.1.8 : "Quit" ferme toutes les fenêtres et termine l'application.
- CT-1.1.9 : Plusieurs éditeurs peuvent être ouverts simultanément (un par image).

### 1.2 Screenshot Watcher (FSEvents)

Surveille un dossier (par défaut `~/Desktop`) pour détecter automatiquement les nouvelles captures d'écran macOS et ouvrir l'éditeur.

**Détection des captures :**
Le watcher identifie les fichiers de capture par leur préfixe de nom :
- `Screenshot` (anglais)
- `Capture d` (français)
- `Bildschirmfoto` (allemand)
- `Captura de pantalla` (espagnol)

Et par leur extension : `.png`, `.jpg`, `.jpeg`, `.tiff`, `.bmp`.

**Debounce :** Les événements FSEvents sont ignorés s'ils arrivent dans les 0.5 secondes suivant le dernier événement traité. Un délai de 0.3 secondes est ajouté avant d'ouvrir le fichier pour s'assurer que macOS a fini d'écrire.

**Fichiers existants :** Au démarrage, le watcher fait un snapshot des fichiers existants dans le dossier. Seuls les **nouveaux** fichiers déclenchent l'ouverture de l'éditeur.

**Cas de test :**
- CT-1.2.1 : Faire Cmd+Shift+4 (capture macOS) avec le dossier de captures sur le Bureau ouvre automatiquement l'éditeur avec la capture.
- CT-1.2.2 : Les fichiers déjà présents au démarrage de l'app ne déclenchent PAS l'éditeur.
- CT-1.2.3 : Un fichier nommé `document.png` copié dans le dossier ne déclenche PAS l'éditeur (pas le bon préfixe).
- CT-1.2.4 : Un fichier `Screenshot 2024-01-15 at 10.30.00.txt` ne déclenche PAS l'éditeur (pas la bonne extension).
- CT-1.2.5 : Deux captures rapides (< 0.5s d'intervalle) : la seconde est ignorée par le debounce.
- CT-1.2.6 : Une capture française `Capture d'écran 2024-01-15 à 10.30.00.png` déclenche l'éditeur.

### 1.3 Préférences

Stockées dans `UserDefaults`. Valeurs configurables :

| Préférence | Clé | Défaut |
|-----------|-----|--------|
| Dossier de captures | `screenshotFolder` | `~/Desktop` |
| Épaisseur de trait | `defaultStrokeWidth` | `2.0` |
| Shadow activé | `defaultShadowEnabled` | `false` |

**Cas de test :**
- CT-1.3.1 : Au premier lancement, `screenshotFolder` vaut `~/Desktop`.
- CT-1.3.2 : Changer `defaultStrokeWidth` persiste entre les lancements.
- CT-1.3.3 : Un `defaultStrokeWidth` de 0 ou négatif retourne la valeur par défaut (2.0).

---

## 2. Fenêtre éditeur

### 2.1 Fenêtre principale (EditorWindowController)

Chaque image ouverte crée une fenêtre indépendante avec :
- **Titre :** nom du fichier source (ou "Untitled" pour les collages clipboard)
- **Taille initiale :** dimensions de l'image, plafonnées à 1200x800 pixels
- **Style :** titled, closable, resizable, miniaturizable
- **Position :** centrée à l'écran

**Cas de test :**
- CT-2.1.1 : Ouvrir une image 500x300 crée une fenêtre de ~540x380 (image + marges).
- CT-2.1.2 : Ouvrir une image 5000x3000 crée une fenêtre plafonnée à 1200x800.
- CT-2.1.3 : Le titre affiche le nom du fichier (ex: "Screenshot 2024-01-15.png").
- CT-2.1.4 : Ouvrir depuis le clipboard affiche "Untitled".
- CT-2.1.5 : Fermer la fenêtre la retire de la liste des éditeurs actifs.
- CT-2.1.6 : La fenêtre est redimensionnable et miniaturisable.

### 2.2 Canvas (CanvasView)

Surface de dessin NSView (coordonnées flippées : origine en haut-gauche) contenue dans un NSScrollView.

**Zoom :** Via NSScrollView magnification (0.1x à 10.0x), défaut 1.0x.

**Scroll :** Scrollbars horizontal et vertical, actifs quand l'image dépasse la fenêtre.

**Rendu :** L'image de fond est dessinée en premier, puis chaque annotation par-dessus dans l'ordre de la liste (z-order = ordre d'insertion).

**Cas de test :**
- CT-2.2.1 : L'image est affichée à l'échelle 1:1 par défaut.
- CT-2.2.2 : Pinch-to-zoom (trackpad) change le niveau de zoom entre 0.1 et 10.0.
- CT-2.2.3 : Les annotations sont dessinées PAR-DESSUS l'image de fond.
- CT-2.2.4 : Une annotation créée plus tard apparaît AU-DESSUS des précédentes.
- CT-2.2.5 : Scroller révèle les parties de l'image hors de la fenêtre.

### 2.3 Toolbar

Barre d'outils macOS native (NSToolbar) avec les boutons suivants, dans cet ordre :

| Bouton | Icône SF Symbol | Action |
|--------|----------------|--------|
| Select | `arrow.uturn.left.circle` | Passe en mode sélection |
| Rectangle | `rectangle` | Outil rectangle |
| Ellipse | `circle` | Outil ellipse |
| Line | `line.diagonal` | Outil ligne |
| Arrow | `arrow.right` | Outil flèche |
| Text | `textformat` | Outil texte |
| Bubble | `bubble.left` | Outil bulle de dialogue |
| Step | `number.circle` | Outil numéro d'étape |
| *(espace flexible)* | | |
| Pixelate | `squareshape.split.3x3` | Outil pixelisation |
| Highlight | `highlighter` | Outil surbrillance |
| Crop | `crop` | Outil recadrage |
| *(espace flexible)* | | |
| Shadow | `shadow` | Active/désactive shadow pour le style courant |
| Copy | `doc.on.clipboard` | Copie l'image annotée dans le clipboard |
| Save | `square.and.arrow.down` | Sauvegarde l'image annotée dans un fichier |

**Cas de test :**
- CT-2.3.1 : Tous les boutons sont visibles dans la toolbar.
- CT-2.3.2 : Cliquer un outil d'annotation change `currentTool` du canvas.
- CT-2.3.3 : Cliquer Shadow toggle `currentStyle.shadow` entre `.default` et `.none`.
- CT-2.3.4 : Cliquer Copy copie l'image finale dans le clipboard (vérifiable en collant dans Preview).
- CT-2.3.5 : Cliquer Save ouvre un NSSavePanel avec PNG et JPEG comme formats.

---

## 3. Annotations

### Comportement commun à toutes les annotations

Chaque annotation possède :
- **id** : UUID unique
- **bounds** : CGRect définissant sa position et ses dimensions
- **style** : AnnotationStyle (strokeColor, fillColor, strokeWidth, fontSize, fontName, shadow)
- **isSelected** : bool, affiche les handles de sélection quand `true`

**Création :** Cliquer-glisser sur le canvas avec un outil actif crée l'annotation. Le point de départ et le point de fin du drag définissent le rectangle englobant.

**Sélection :** En mode Select, cliquer sur une annotation la sélectionne (affiche les handles). Cliquer dans le vide désélectionne.

**Déplacement :** En mode Select, cliquer-glisser sur une annotation sélectionnée la déplace.

**Redimensionnement :** 8 handles (coins + milieux des côtés). Cliquer-glisser un handle redimensionne l'annotation.

**Suppression :** Touche Delete ou Forward Delete supprime l'annotation sélectionnée.

**Seuil de création :** Si le drag produit un rectangle de moins de 4x4 pixels, l'annotation est supprimée automatiquement (clic accidentel).

**Retour au mode Select :** Après la création d'une annotation, l'outil repasse automatiquement en mode Select.

**Cas de test :**
- CT-3.0.1 : Cliquer-glisser en mode Rectangle crée un rectangle aux dimensions du drag.
- CT-3.0.2 : Un micro-drag (< 4px) ne crée pas d'annotation.
- CT-3.0.3 : Après création, l'outil repasse en Select.
- CT-3.0.4 : Cliquer une annotation en mode Select la sélectionne (handles visibles).
- CT-3.0.5 : Cliquer dans le vide désélectionne l'annotation courante.
- CT-3.0.6 : Glisser une annotation sélectionnée la déplace.
- CT-3.0.7 : Glisser un handle redimensionne l'annotation.
- CT-3.0.8 : Touche Delete supprime l'annotation sélectionnée.
- CT-3.0.9 : Quand plusieurs annotations se chevauchent, cliquer sélectionne celle du dessus (z-order inversé).
- CT-3.0.10 : Le hit test inclut une tolérance de 4px autour des bounds.

### 3.1 Rectangle

Dessine un rectangle avec contour (`strokeColor`, `strokeWidth`) et optionnellement un remplissage (`fillColor`).

**Cas de test :**
- CT-3.1.1 : Le rectangle est dessiné avec la couleur et l'épaisseur du style courant.
- CT-3.1.2 : Avec un `fillColor` non-clear, l'intérieur est rempli.
- CT-3.1.3 : Avec shadow activé, une ombre est visible sous le rectangle.
- CT-3.1.4 : Le rectangle peut être redimensionné via les 8 handles.

### 3.2 Ellipse

Identique au rectangle mais dessine une ellipse inscrite dans les bounds.

**Cas de test :**
- CT-3.2.1 : L'ellipse est inscrite dans le rectangle de bounds.
- CT-3.2.2 : Avec un bounds carré, l'ellipse est un cercle.
- CT-3.2.3 : Shadow fonctionne sur l'ellipse.

### 3.3 Ligne

Dessine une ligne droite du coin top-left au coin bottom-right des bounds.

**Hit test :** Basé sur la distance perpendiculaire du point à la ligne (tolérance de 6px), pas sur les bounds rectangulaires.

**Cas de test :**
- CT-3.3.1 : La ligne est dessinée entre startPoint (minX, minY) et endPoint (maxX, maxY).
- CT-3.3.2 : Le hit test détecte un clic à 5px de la ligne.
- CT-3.3.3 : Le hit test rejette un clic à 10px de la ligne.
- CT-3.3.4 : Le hit test rejette un clic dans le prolongement de la ligne (hors du segment).
- CT-3.3.5 : Une ligne de longueur zéro (clic sans drag suffisant) est correctement gérée.

### 3.4 Flèche

Comme la ligne, mais avec une **pointe triangulaire** à l'extrémité (endPoint).

**Pointe :** Triangle fermé et rempli avec `strokeColor`. Taille = `10 + strokeWidth * 2`. Angle d'ouverture = 30 degrés de chaque côté de l'axe de la ligne. La direction de la pointe suit l'angle de la ligne.

**Cas de test :**
- CT-3.4.1 : La flèche affiche une pointe triangulaire pleine à son extrémité.
- CT-3.4.2 : La pointe est orientée dans la direction de la ligne.
- CT-3.4.3 : Augmenter `strokeWidth` agrandit la pointe proportionnellement.
- CT-3.4.4 : La pointe est remplie avec `strokeColor` (pas `fillColor`).
- CT-3.4.5 : Le hit test fonctionne comme pour la ligne (distance au segment).

### 3.5 Texte

Boîte de texte avec un texte par défaut "Text".

**Taille initiale :** 150x30 pixels (ne suit pas le drag comme les autres annotations).

**Rendu :** Le texte est dessiné avec CoreText (CTFramesetter + CTFrameDraw) en utilisant `style.fontName`, `style.fontSize`, et `style.strokeColor`.

**Cas de test :**
- CT-3.5.1 : Cliquer avec l'outil Texte crée une boîte avec le texte "Text".
- CT-3.5.2 : La taille initiale est 150x30 pixels.
- CT-3.5.3 : Le texte utilise la police et la taille du style courant.
- CT-3.5.4 : La couleur du texte est `strokeColor`.
- CT-3.5.5 : La copie (`copy()`) préserve le texte.
- CT-3.5.6 : Shadow fonctionne sur le texte.

### 3.6 Bulle de dialogue (Speech Bubble)

Boîte de texte avec un corps arrondi (rounded rect, rayon 8px) et une **queue triangulaire** pointant vers un point configurable.

**Taille initiale :** 150x60 pixels.

**Queue :** Triangle depuis le milieu du bord inférieur du corps vers `tailPoint`. Largeur de la queue = min(20px, 30% de la largeur du corps). Par défaut, `tailPoint` est 30px sous le centre du bord inférieur.

**Texte :** Dessiné à l'intérieur du corps avec un inset de 6px horizontal et 4px vertical.

**Hit test :** Détecte les clics dans le corps (bounds + 4px tolérance) OU dans le triangle de la queue (test par coordonnées barycentriques).

**Cas de test :**
- CT-3.6.1 : La bulle affiche un corps arrondi avec une queue triangulaire.
- CT-3.6.2 : Le texte "Text" est affiché à l'intérieur du corps.
- CT-3.6.3 : Cliquer dans le corps sélectionne la bulle.
- CT-3.6.4 : Cliquer dans le triangle de la queue sélectionne aussi la bulle.
- CT-3.6.5 : Cliquer en dehors du corps et de la queue ne sélectionne pas.
- CT-3.6.6 : La copie préserve le texte et la position de `tailPoint`.
- CT-3.6.7 : `tailPoint` peut être modifié programmatiquement.

### 3.7 Numéros d'étapes (Step Labels)

Cercle coloré avec un numéro centré, auto-incrémenté.

**Taille :** Cercle de 30x30 pixels, centré sur le point de clic.

**Couleur :** Le cercle est rempli avec `fillColor` (ou `systemRed` si `fillColor` est `.clear`). Le numéro est en blanc, gras, taille = `style.fontSize`.

**Auto-incrémentation :** Un compteur statique (`nextStepNumber`) attribue automatiquement 1, 2, 3... à chaque nouveau step label. `resetCounter()` remet le compteur à 1.

**Hit test :** Basé sur la distance au centre du cercle (rayon + 4px tolérance).

**Copie :** `copy()` préserve le `stepNumber` sans incrémenter le compteur.

**Cas de test :**
- CT-3.7.1 : Le premier step label porte le numéro 1, le deuxième le 2, etc.
- CT-3.7.2 : `resetCounter()` remet le prochain numéro à 1.
- CT-3.7.3 : Le cercle est centré sur le point de clic.
- CT-3.7.4 : Le cercle est rempli en rouge par défaut.
- CT-3.7.5 : Le numéro est blanc, centré dans le cercle.
- CT-3.7.6 : Cliquer à l'intérieur du cercle (distance < rayon + 4) sélectionne.
- CT-3.7.7 : Cliquer à l'extérieur du cercle ne sélectionne pas.
- CT-3.7.8 : La copie préserve le stepNumber sans incrémenter le compteur global.

---

## 4. Shadow

Propriété configurable sur toutes les annotations via `ShadowStyle` :

| Propriété | Type | Défaut |
|-----------|------|--------|
| enabled | Bool | `true` |
| offset | CGSize | `(2, -2)` |
| blurRadius | CGFloat | `4` |
| color | NSColor | `black` à 50% opacité |

**Application :** Avant le rendu de chaque annotation, `style.shadow.apply(to: context)` appelle `CGContext.setShadow(offset:blur:color:)`.

**`ShadowStyle.none` :** Variante prédéfinie avec `enabled = false`, pas de shadow rendu.

**Toggle :** Le bouton Shadow dans la toolbar bascule `currentStyle.shadow` entre `.default` et `.none` pour les prochaines annotations créées.

**Exception :** Les `HighlightFilter` utilisent toujours `ShadowStyle.none` (une ombre sur un surligneur n'a pas de sens).

**Cas de test :**
- CT-4.1 : `ShadowStyle.default` a `enabled = true`, offset (2, -2), blur 4.
- CT-4.2 : `ShadowStyle.none` a `enabled = false`.
- CT-4.3 : Deux `ShadowStyle.default` sont égaux (Equatable).
- CT-4.4 : `.default` et `.none` ne sont pas égaux.
- CT-4.5 : Un rectangle créé avec shadow activé affiche une ombre visible.
- CT-4.6 : Un rectangle créé avec shadow désactivé n'affiche pas d'ombre.
- CT-4.7 : Le toggle toolbar change le style des prochaines annotations, pas des existantes.

---

## 5. Filtres

### 5.1 Pixelisation

Zone rectangulaire indiquant que la région sera pixelisée au rendu final.

**Visuel en édition :** Overlay gris semi-transparent (15% opacité) avec une grille de lignes (espacement 8px, 30% opacité de strokeColor) et un contour pointillé (tirets 6px, espaces 4px).

**Note :** La pixelisation réelle des pixels de l'image de fond n'est pas encore implémentée. L'indication visuelle sert de marqueur pour un traitement futur ou pour le rendu final.

**Cas de test :**
- CT-5.1.1 : Cliquer-glisser avec l'outil Pixelate crée une zone avec overlay gris et grille.
- CT-5.1.2 : La zone a un contour pointillé (pas continu).
- CT-5.1.3 : Le hit test fonctionne normalement (bounds + tolérance).
- CT-5.1.4 : La zone peut être déplacée et redimensionnée.
- CT-5.1.5 : La copie crée une zone indépendante.

### 5.2 Surbrillance (Highlight)

Rectangle semi-transparent coloré, comme un marqueur jaune.

**Couleur par défaut :** `NSColor.yellow` à 40% opacité.
**Shadow :** Toujours désactivé (`ShadowStyle.none`), même si le style courant a shadow activé.

**Cas de test :**
- CT-5.2.1 : Cliquer-glisser avec l'outil Highlight crée un rectangle jaune semi-transparent.
- CT-5.2.2 : Le highlight n'a PAS de shadow, même si shadow est activé dans le style.
- CT-5.2.3 : Un style custom avec une autre couleur est respecté.
- CT-5.2.4 : La zone peut être déplacée et redimensionnée.

---

## 6. Crop (Recadrage)

### Comportement

1. Sélectionner l'outil Crop dans la toolbar.
2. Cliquer-glisser dessine un rectangle bleu semi-transparent (contour bleu, remplissage bleu à 10%, pas de shadow).
3. Au relâchement de la souris, le crop est appliqué immédiatement :
   - L'image de fond est recadrée à la zone sélectionnée.
   - Toutes les annotations sont repositionnées (leur origin est décalée de l'origin du crop rect).
   - Les annotations complètement hors de la nouvelle zone sont supprimées.
   - Le canvas est redimensionné aux nouvelles dimensions.
4. L'outil repasse en mode Select.

**Handling Retina :** Le crop prend en compte le scale factor de l'écran (`CGImage.width / NSImage.size.width`).

**Cas de test :**
- CT-6.1 : Crop d'une image 300x200 avec rect (50, 40, 200, 120) produit une image de 200x120.
- CT-6.2 : Après crop, une annotation à (100, 80) est déplacée à (50, 40) [100-50, 80-40].
- CT-6.3 : Une annotation à (10, 10) dans un crop commençant à (100, 60) est supprimée (hors zone).
- CT-6.4 : Le canvas frame est redimensionné aux dimensions du crop.
- CT-6.5 : Le rectangle de crop est un rectangle bleu temporaire, pas une annotation permanente.
- CT-6.6 : Après crop, l'outil est en mode Select.
- CT-6.7 : Un crop rect plus grand que l'image ne cause pas de crash.

---

## 7. Undo / Redo

Basé sur `NSUndoManager`. Chaque action enregistre son inverse.

### Actions supportées

| Action | Undo | Redo |
|--------|------|------|
| Ajouter une annotation | Supprime l'annotation | Rajoute l'annotation |
| Supprimer une annotation | Réinsère l'annotation à son index original | Resupprime |
| Déplacer/redimensionner | Restaure les bounds et le style originaux | Restaure les bounds modifiés |

**Raccourcis :** Cmd+Z (undo), Cmd+Shift+Z (redo) — gérés automatiquement par la responder chain via `undoManager`.

**Cas de test :**
- CT-7.1 : Créer un rectangle puis Cmd+Z le supprime.
- CT-7.2 : Après undo, Cmd+Shift+Z le recrée.
- CT-7.3 : Déplacer une annotation puis Cmd+Z la ramène à sa position d'origine.
- CT-7.4 : Supprimer une annotation puis Cmd+Z la réinsère.
- CT-7.5 : Undo/Redo multiples en séquence fonctionnent correctement.

---

## 8. Export

### 8.1 Copie dans le clipboard

`ClipboardExporter.copy(image:)` : écrit l'image dans `NSPasteboard.general`.

Le rendu final (`renderFinalImage()`) :
1. Crée une nouvelle NSImage aux dimensions de l'image de fond.
2. Dessine l'image de fond.
3. Désélectionne l'annotation courante (pour masquer les handles).
4. Dessine toutes les annotations.
5. Restaure la sélection.

**Cas de test :**
- CT-8.1.1 : Copier une image sans annotations place l'image originale dans le clipboard.
- CT-8.1.2 : Copier une image avec annotations inclut les annotations dans l'image du clipboard.
- CT-8.1.3 : Les handles de sélection ne sont PAS visibles dans l'image exportée.
- CT-8.1.4 : L'image du clipboard peut être collée dans Preview/Pages/etc.

### 8.2 Sauvegarde fichier

`FileExporter.save(image:suggestedName:from:)` :
- Ouvre un `NSSavePanel` avec types autorisés PNG et JPEG.
- Nom suggéré : nom du fichier source (sans extension) ou `Annotated YYYY-MM-DD at HH.mm.ss`.
- Pour JPEG : compression à 90%.

`FileExporter.quickSave(image:to:format:)` : sauvegarde directe dans un dossier sans dialogue.

**Cas de test :**
- CT-8.2.1 : Sauvegarder en PNG crée un fichier PNG valide.
- CT-8.2.2 : Sauvegarder en JPEG crée un fichier JPEG valide.
- CT-8.2.3 : Le nom par défaut contient la date et l'heure.
- CT-8.2.4 : `quickSave` crée le fichier dans le dossier spécifié avec le bon format.
- CT-8.2.5 : L'image sauvegardée inclut les annotations.
- CT-8.2.6 : Annuler le NSSavePanel ne crée pas de fichier.

---

## 9. Handles de sélection

8 positions de handle autour d'une annotation sélectionnée :

```
TopLeft ---- TopCenter ---- TopRight
  |                            |
MiddleLeft               MiddleRight
  |                            |
BottomLeft - BottomCenter - BottomRight
```

**Visuel :** Petit carré blanc (8x8 pixels) avec contour bleu (`controlAccentColor`). Border pointillée autour de l'annotation.

**Hit test des handles :** Carré de 8x8 centré sur le point du handle. Priorité sur le hit test de l'annotation (un clic sur un handle redimensionne, pas déplace).

**Redimensionnement :** Chaque handle contrôle un sous-ensemble des propriétés du bounds (origin et/ou size). Le résultat est toujours standardisé (pas de dimensions négatives).

**Cas de test :**
- CT-9.1 : Une annotation sélectionnée affiche 8 handles blancs avec contour bleu.
- CT-9.2 : Une annotation non sélectionnée n'affiche PAS de handles.
- CT-9.3 : Glisser le handle BottomRight agrandit l'annotation vers la droite et le bas.
- CT-9.4 : Glisser le handle TopLeft déplace l'origin et change la taille.
- CT-9.5 : Glisser un handle au-delà du côté opposé produit un rectangle standardisé (pas de taille négative).
- CT-9.6 : Les handles MiddleLeft/MiddleRight ne modifient que la largeur.
- CT-9.7 : Les handles TopCenter/BottomCenter ne modifient que la hauteur.

---

## 10. Style des annotations (AnnotationStyle)

| Propriété | Type | Défaut |
|-----------|------|--------|
| strokeColor | NSColor | `.systemRed` |
| fillColor | NSColor | `.clear` |
| strokeWidth | CGFloat | `2.0` |
| fontSize | CGFloat | `14.0` |
| fontName | String | `"Helvetica"` |
| shadow | ShadowStyle | `.default` |

Le style courant (`canvasView.currentStyle`) est appliqué à chaque nouvelle annotation au moment de sa création. Modifier le style courant n'affecte pas les annotations existantes.

**Cas de test :**
- CT-10.1 : Une annotation créée utilise le style courant du canvas au moment de la création.
- CT-10.2 : Modifier le style courant après création ne change pas les annotations existantes.
- CT-10.3 : Chaque annotation a sa propre copie du style (pas de partage par référence).
