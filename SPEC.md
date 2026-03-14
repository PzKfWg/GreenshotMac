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
| Ouvrir une image... | Cmd+O | Ouvre un `NSOpenPanel` filtré sur PNG, JPEG, TIFF, BMP. Ouvre l'éditeur avec l'image sélectionnée. |
| Coller depuis le presse-papiers | Cmd+V | Lit une image depuis `NSPasteboard.general`. Si une image est présente, ouvre l'éditeur avec. Sinon, ne fait rien (pas d'alerte). |
| Préférences... | Cmd+, | Ouvre la fenêtre de préférences (stub pour l'instant). |
| Quitter GreenshotMac | Cmd+Q | Ferme l'application. |

**Cas de test :**
- CT-1.1.1 : Au lancement, l'icône apparaît dans la barre de menu.
- CT-1.1.2 : L'application n'apparaît PAS dans le Dock.
- CT-1.1.3 : Cliquer l'icône affiche le menu avec les 5 items (Ouvrir une image, Coller depuis le presse-papiers, séparateur, Préférences, séparateur, Quitter).
- CT-1.1.4 : "Ouvrir une image..." ouvre un NSOpenPanel. Sélectionner un PNG ouvre l'éditeur avec cette image.
- CT-1.1.5 : "Ouvrir une image..." avec annulation ne fait rien.
- CT-1.1.6 : "Coller depuis le presse-papiers" avec une image dans le clipboard ouvre l'éditeur.
- CT-1.1.7 : "Coller depuis le presse-papiers" sans image dans le clipboard ne fait rien (pas de crash, pas d'alerte).
- CT-1.1.8 : "Quitter" ferme toutes les fenêtres et termine l'application.
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
| Couleur de contour | `defaultStrokeColorData` | `.systemRed` |
| Couleur de fond | `defaultFillColorData` | `.clear` |
| Shadow activé | `defaultShadowEnabled` | `false` |

Les couleurs sont persistées via `NSKeyedArchiver` (préserve l'espace colorimétrique et l'alpha).

**Cas de test :**
- CT-1.3.1 : Au premier lancement, `screenshotFolder` vaut `~/Desktop`.
- CT-1.3.2 : Changer `defaultStrokeWidth` persiste entre les lancements.
- CT-1.3.3 : Un `defaultStrokeWidth` de 0 ou négatif retourne la valeur par défaut (2.0).
- CT-1.3.4 : Changer `defaultStrokeColor` persiste entre les lancements (alpha inclus).
- CT-1.3.5 : Changer `defaultFillColor` persiste entre les lancements (alpha inclus).

---

## 2. Fenêtre éditeur

### 2.1 Fenêtre principale (EditorWindowController)

Chaque image ouverte crée une fenêtre indépendante avec :
- **Titre :** nom du fichier source (ou "Sans titre" pour les collages clipboard)
- **Taille initiale :** dimensions de l'image + sidebar, plafonnées à 1200x800 pixels
- **Style :** titled, closable, resizable, miniaturizable
- **Position :** centrée à l'écran
- **Layout :** sidebar outils à gauche (largeur fixe 80pt) + canvas à droite

```
NSToolbar: [Contour ◼ | Fond ◼ | Épaisseur ▾ | ── | Ombre | ── | Copier | Enregistrer]
┌──────────┬─────────────────────────────────────┐
│ Sidebar  │                                     │
│ (2 cols) │         NSScrollView                │
│          │         CanvasView                  │
│ [⬚] [⬭] │                                     │
│ [╱] [→]  │                                     │
│ [A] [💬] │                                     │
│ [①] [▦]  │                                     │
│ [🖍] [⬒] │                                     │
└──────────┴─────────────────────────────────────┘
```

**Cas de test :**
- CT-2.1.1 : Ouvrir une image 500x300 crée une fenêtre de ~620x380 (image + sidebar + marges).
- CT-2.1.2 : Ouvrir une image 5000x3000 crée une fenêtre plafonnée à 1200x800.
- CT-2.1.3 : Le titre affiche le nom du fichier (ex: "Screenshot 2024-01-15.png").
- CT-2.1.4 : Ouvrir depuis le clipboard affiche "Sans titre".
- CT-2.1.5 : Fermer la fenêtre la retire de la liste des éditeurs actifs.
- CT-2.1.6 : La fenêtre est redimensionnable et miniaturisable.
- CT-2.1.7 : La sidebar reste à largeur fixe lors du redimensionnement, le canvas s'adapte.

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

### 2.3 Barre latérale d'outils (ToolSidebarView)

Panneau fixe à gauche (80pt de large) contenant les outils d'annotation en grille 2 colonnes. Chaque bouton est un `NSButton` toggle avec icône SF Symbol.

| Col 1 | Col 2 |
|-------|-------|
| Sélection (`arrow.uturn.left.circle`) | Rectangle (`rectangle`) |
| Ellipse (`circle`) | Ligne (`line.diagonal`) |
| Flèche (`arrow.right`) | Texte (`textformat`) |
| Bulle (`bubble.left`) | Étape (`number.circle`) |
| *(séparateur)* | |
| Pixeliser (`squareshape.split.3x3`) | Surligner (`highlighter`) |
| Recadrer (`crop`) | |

- Sélection exclusive : un seul outil actif à la fois (visuellement enfoncé)
- Mise à jour programmatique quand le canvas revient en mode Sélection après création

**Cas de test :**
- CT-2.3.1 : Tous les boutons d'outils sont visibles dans la sidebar.
- CT-2.3.2 : Cliquer un outil d'annotation change `currentTool` du canvas.
- CT-2.3.3 : Un seul bouton est enfoncé à la fois (sélection exclusive).
- CT-2.3.4 : Après création d'une annotation, la sidebar revient à Sélection.
- CT-2.3.5 : Un séparateur visuel sépare les outils d'annotation des filtres.
- CT-2.3.6 : Tous les libellés d'outils sont en français (Sélection, Rectangle, Ellipse, Ligne, Flèche, Texte, Bulle, Étape, Pixeliser, Surligner, Recadrer).

### 2.4 Toolbar de style (NSToolbar)

Barre d'outils macOS native en haut de la fenêtre, contenant les contrôles de style et les actions :

| Élément | Type | Description |
|---------|------|-------------|
| Contour | `NSColorWell` (style `.minimal`) | Couleur de contour, avec support alpha/transparence |
| Fond | `NSColorWell` (style `.minimal`) | Couleur de fond, avec support alpha/transparence |
| Épaisseur | `NSPopUpButton` | Épaisseur de trait (1, 2, 3, 5, 8, 12 pt) |
| *(espace flexible)* | | |
| Ombre | Bouton icône `shadow` | Active/désactive shadow pour le style courant |
| *(espace flexible)* | | |
| Copier | Bouton icône `doc.on.clipboard` | Copie l'image annotée dans le clipboard |
| Enregistrer | Bouton icône `square.and.arrow.down` | Sauvegarde l'image annotée dans un fichier |

**Visibilité contextuelle des contrôles :** Les color wells et le popup d'épaisseur sont montrés/cachés selon l'outil actif ou l'annotation sélectionnée :

| Annotation | Contour | Fond | Épaisseur |
|------------|---------|------|-----------|
| Rectangle | ✓ | ✓ | ✓ |
| Ellipse | ✓ | ✓ | ✓ |
| Line | ✓ | — | ✓ |
| Arrow | ✓ | — | ✓ |
| Text | ✓ (couleur texte) | — | — |
| SpeechBubble | ✓ | ✓ | ✓ |
| StepLabel | — | — | — |
| Pixelate | — | — | — |
| Highlight | — | — | — |
| Crop | — | — | — |

**Comportement :**
- Changer une couleur ou épaisseur met à jour `canvasView.currentStyle` pour les prochaines annotations
- Si une annotation est sélectionnée, le changement s'applique aussi immédiatement (édition live)
- Les changements de style sur annotation sélectionnée sont enregistrés dans l'undo manager (noms d'action en français)
- Les couleurs et épaisseur sont persistées dans `Preferences` entre les sessions
- `NSColorPanel.shared.showsAlpha = true` pour permettre la transparence

**Cas de test :**
- CT-2.4.1 : Les color wells et popup épaisseur sont visibles pour l'outil Rectangle.
- CT-2.4.2 : Seul le color well Contour est visible pour l'outil Texte.
- CT-2.4.3 : Aucun contrôle de style n'est visible pour l'outil Pixeliser.
- CT-2.4.4 : Changer la couleur Contour met à jour `currentStyle.strokeColor`.
- CT-2.4.5 : Changer la couleur Fond met à jour `currentStyle.fillColor`.
- CT-2.4.6 : Changer l'épaisseur met à jour `currentStyle.strokeWidth`.
- CT-2.4.7 : Sélectionner une annotation met à jour les contrôles avec son style.
- CT-2.4.8 : Modifier la couleur d'une annotation sélectionnée met à jour son rendu immédiatement.
- CT-2.4.9 : Undo après modification de style restaure l'ancien style.
- CT-2.4.10 : Cliquer Ombre toggle `currentStyle.shadow` entre `.default` et `.none`.
- CT-2.4.11 : Cliquer Copier copie l'image finale dans le clipboard.
- CT-2.4.12 : Cliquer Enregistrer ouvre un NSSavePanel avec PNG et JPEG comme formats.

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

**Hit test (aligné avec Greenshot Windows EllipseContainer.Contains) :**
- Utilise l'équation de l'ellipse `x²/a² + y²/b² ≤ 1` au lieu d'un test rectangulaire.
- **Remplie :** tout point à l'intérieur de l'ellipse (+ tolérance) est détecté.
- **Non remplie :** seuls les points proches du contour (entre ellipse interne et externe avec tolérance) sont détectés. Le centre de l'ellipse ne trigger pas le hit test.
- Tolérance = `max(4, strokeWidth + 4)` pixels.

**Cas de test :**
- CT-3.2.1 : L'ellipse est inscrite dans le rectangle de bounds.
- CT-3.2.2 : Avec un bounds carré, l'ellipse est un cercle.
- CT-3.2.3 : Shadow fonctionne sur l'ellipse.
- CT-3.2.4 : Le hit test sur le contour de l'ellipse détecte un clic.
- CT-3.2.5 : Le hit test au centre d'une ellipse non remplie ne détecte pas.
- CT-3.2.6 : Le hit test au centre d'une ellipse remplie détecte.
- CT-3.2.7 : Le hit test au coin du bounding rect d'une ellipse remplie ne détecte pas (coin extérieur à l'ellipse).
- CT-3.2.8 : Le hit test fonctionne sur une ellipse très étroite.

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

Comme la ligne, mais avec une ou deux **pointes triangulaires** aux extrémités.

**ArrowHeadCombination :** Contrôle quelles extrémités portent une pointe. Valeurs possibles : `.none`, `.startPoint`, `.endPoint` (par défaut), `.both`. Aligné avec l'enum `ArrowHeadCombination` de Greenshot Windows.

**Pointe :** Triangle fermé et rempli avec `strokeColor`. Dimensions proportionnelles au `strokeWidth`, calquées sur `AdjustableArrowCap(4, 6)` de Greenshot Windows :
- **Largeur** = `4 × strokeWidth` (la base du triangle)
- **Hauteur** = `6 × strokeWidth` (la profondeur du triangle depuis la pointe)
- La direction de la pointe suit l'angle de la ligne.

**Hit test :** Teste la distance au segment de ligne (tolérance = `max(6, strokeWidth + 4)` px) ET l'appartenance au triangle de chaque pointe active (test par coordonnées barycentriques).

**Cas de test :**
- CT-3.4.1 : La flèche affiche une pointe triangulaire pleine à son extrémité par défaut (`.endPoint`).
- CT-3.4.2 : La pointe est orientée dans la direction de la ligne.
- CT-3.4.3 : La largeur de la pointe = `4 × strokeWidth`, la hauteur = `6 × strokeWidth`.
- CT-3.4.4 : La pointe est remplie avec `strokeColor` (pas `fillColor`).
- CT-3.4.5 : Le hit test détecte les clics sur la ligne ET sur le triangle de la pointe.
- CT-3.4.6 : `ArrowHeadCombination.both` affiche des pointes aux deux extrémités.
- CT-3.4.7 : `ArrowHeadCombination.none` n'affiche aucune pointe; le hit test ne détecte que le segment.
- CT-3.4.8 : `ArrowHeadCombination.startPoint` affiche la pointe au point de départ uniquement.
- CT-3.4.9 : `copy()` préserve le réglage `arrowHeads`.
- CT-3.4.10 : La tolérance du hit test augmente avec le `strokeWidth`.

### 3.5 Texte

Boîte de texte avec un texte par défaut "Texte".

**Taille initiale :** 150x30 pixels (ne suit pas le drag comme les autres annotations).

**Rendu :** Le texte est dessiné avec CoreText (CTFramesetter + CTFrameDraw) en utilisant `style.fontName`, `style.fontSize`, et `style.strokeColor`.

**Gras/Italique :** Les propriétés `style.fontBold` et `style.fontItalic` (booléens, défaut `false`) contrôlent le style du texte. La résolution de police utilise `NSFontManager.convert(_:toHaveTrait:)` pour appliquer les traits bold/italic, avec fallback sur la police système si la police demandée n'existe pas. Aligné avec les champs `FONT_BOLD` et `FONT_ITALIC` de Greenshot Windows.

**Alignement horizontal :** `style.textHorizontalAlignment` (`.left`, `.center`, `.right`), défaut `.center`. Appliqué via `NSParagraphStyle.alignment` dans les attributs CoreText. Aligné avec `TEXT_HORIZONTAL_ALIGNMENT` de Greenshot Windows (StringAlignment.Near/Center/Far).

**Alignement vertical :** `style.textVerticalAlignment` (`.top`, `.center`, `.bottom`), défaut `.center`. Calculé en mesurant la hauteur du texte via `CTFramesetterSuggestFrameSizeWithConstraints` et en décalant le rect de dessin. Aligné avec `TEXT_VERTICAL_ALIGNMENT` de Greenshot Windows.

**Édition inline :** À FAIRE — Greenshot Windows utilise un TextBox overlay avec double-click, ESC/Enter pour fermer, support IME, et synchronisation bidirectionnelle via data binding.

**Cas de test :**
- CT-3.5.1 : Cliquer avec l'outil Texte crée une boîte avec le texte "Texte".
- CT-3.5.2 : La taille initiale est 150x30 pixels.
- CT-3.5.3 : Le texte utilise la police et la taille du style courant.
- CT-3.5.4 : La couleur du texte est `strokeColor`.
- CT-3.5.5 : La copie (`copy()`) préserve le texte, le gras/italique et l'alignement.
- CT-3.5.6 : Shadow fonctionne sur le texte.
- CT-3.5.7 : `fontBold = true` produit une police avec le trait bold.
- CT-3.5.8 : `fontItalic = true` produit une police avec le trait italic.
- CT-3.5.9 : `fontBold = true` et `fontItalic = true` combinés produisent bold+italic.
- CT-3.5.10 : Police inexistante → fallback sur la police système.
- CT-3.5.11 : Alignement horizontal/vertical par défaut = center/center.
- CT-3.5.12 : Les 3 valeurs d'alignement horizontal (left/center/right) sont supportées.
- CT-3.5.13 : Les 3 valeurs d'alignement vertical (top/center/bottom) sont supportées.

### 3.6 Bulle de dialogue (Speech Bubble)

Boîte de texte avec un corps arrondi et une **queue triangulaire** pointant vers un point configurable. Hérite conceptuellement de TextContainer dans Greenshot Windows (SpeechbubbleContainer extends TextContainer).

**Taille initiale :** 150x60 pixels.

**Style par défaut (aligné avec Greenshot Windows) :**
- `strokeColor` = bleu (`.systemBlue`) — Windows: `Color.Blue`
- `fillColor` = blanc (`.white`) — Windows: `Color.White`
- `fontBold` = `true` — Windows: `FONT_BOLD = true`
- `fontSize` = 20.0 — Windows: `FONT_SIZE = 20f`
- `shadow` = désactivé — Windows: `SHADOW = false`
- Un style personnalisé peut être passé pour remplacer ces défauts.

**Corps arrondi (corner radius adaptatif, aligné avec Greenshot Windows) :**
- Rayon = `min(30, smallerSide / 2 - strokeWidth)`, minimum 0.
- Pour les grandes bulles, le rayon est plafonné à 30px.
- Pour les petites bulles, le rayon se réduit proportionnellement.
- Si le rayon atteint 0, un rectangle simple est utilisé.

**Queue (tail width formula alignée avec Greenshot Windows) :**
- Largeur = `(|width| + |height|) / 20`, plafonnée à la moitié de chaque dimension, minimum 4px.
- Triangle depuis le milieu du bord inférieur du corps vers `tailPoint`.
- Par défaut, `tailPoint` est 30px sous le centre du bord inférieur.

**Texte :** Dessiné à l'intérieur du corps avec un inset de 6px horizontal et 4px vertical. Supporte gras/italique et alignement horizontal/vertical (mêmes propriétés que TextAnnotation).

**Hit test :** Détecte les clics dans le corps (bounds + 4px tolérance) OU dans le triangle de la queue (test par coordonnées barycentriques).

**Cas de test :**
- CT-3.6.1 : La bulle affiche un corps arrondi avec une queue triangulaire.
- CT-3.6.2 : Le texte "Texte" est affiché à l'intérieur du corps.
- CT-3.6.3 : Cliquer dans le corps sélectionne la bulle.
- CT-3.6.4 : Cliquer dans le triangle de la queue sélectionne aussi la bulle.
- CT-3.6.5 : Cliquer en dehors du corps et de la queue ne sélectionne pas.
- CT-3.6.6 : La copie préserve le texte et la position de `tailPoint`.
- CT-3.6.7 : `tailPoint` peut être modifié programmatiquement.
- CT-3.6.8 : Style par défaut = bleu, fond blanc, gras, 20pt, pas d'ombre.
- CT-3.6.9 : Corner radius adaptatif : 30px max, réduit pour petites bulles.
- CT-3.6.10 : Corner radius = 0 pour bulles très petites.
- CT-3.6.11 : Tail width suit la formule `(w+h)/20`, plafonnée et minimale.
- CT-3.6.12 : Un style personnalisé remplace les défauts.

### 3.7 Numéros d'étapes (Step Labels)

Cercle coloré avec un numéro centré, auto-incrémenté.

**Taille :** Cercle de 30x30 pixels, centré sur le point de clic.

**Couleur :** Le cercle est rempli avec `fillColor` (ou `systemRed` si `fillColor` est `.clear`). Le numéro est en blanc, gras, taille = `style.fontSize`.

**Auto-incrémentation :** Un compteur statique (`nextStepNumber`) attribue automatiquement des numéros séquentiels à chaque nouveau step label. `resetCounter()` remet le compteur à 1. `setCounter(to:)` permet de définir le numéro de départ (minimum 1). `currentCounter` retourne la valeur actuelle du compteur.

**Numéro de départ configurable :** Un stepper dans la barre d'outils (visible quand l'outil Step est sélectionné) permet de choisir le numéro de départ (1-999). La valeur est persistée dans les préférences (`stepLabelStartNumber`). Changer le numéro de départ met à jour le compteur pour le prochain step label créé.

**Hit test :** Basé sur la distance au centre du cercle (rayon + 4px tolérance).

**Copie :** `copy()` préserve le `stepNumber` sans incrémenter le compteur.

**Cas de test :**
- CT-3.7.1 : Le premier step label porte le numéro configuré (défaut 1), le deuxième l'incrémente, etc.
- CT-3.7.2 : `resetCounter()` remet le prochain numéro à 1.
- CT-3.7.3 : Le cercle est centré sur le point de clic.
- CT-3.7.4 : Le cercle est rempli en rouge par défaut.
- CT-3.7.5 : Le numéro est blanc, centré dans le cercle.
- CT-3.7.6 : Cliquer à l'intérieur du cercle (distance < rayon + 4) sélectionne.
- CT-3.7.7 : Cliquer à l'extérieur du cercle ne sélectionne pas.
- CT-3.7.8 : La copie préserve le stepNumber sans incrémenter le compteur global.
- CT-3.7.9 : `setCounter(to: 5)` fait que le prochain step label porte le numéro 5.
- CT-3.7.10 : `setCounter(to:)` avec une valeur < 1 utilise 1 comme minimum.
- CT-3.7.11 : Le stepper "Début #" est visible uniquement quand l'outil Étape est sélectionné.

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

**Toggle :** Le bouton Ombre dans la toolbar bascule `currentStyle.shadow` entre `.default` et `.none` pour les prochaines annotations créées.

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

Zone rectangulaire qui pixelise la région de l'image de fond en temps réel.

**Algorithme :** Utilise le filtre Core Image `CIPixellate` pour moyenner les couleurs en blocs de `pixelSize × pixelSize` pixels (même approche que Greenshot Windows).

**Propriété `pixelSize` :** Taille des blocs de pixels (défaut : 5). Configurable via le popup "Taille pixel" dans la toolbar, visible uniquement quand l'outil Pixeliser est sélectionné ou qu'un PixelateFilter est sélectionné. Valeurs proposées : 3, 5, 7, 9, 12, 15, 20 px.

**Visuel en édition :** Pixelisation réelle de l'image de fond + contour pointillé gris (tirets 6px, espaces 4px). Si l'image de fond n'est pas disponible ou `pixelSize ≤ 1`, un placeholder est affiché (overlay gris 15% + grille 8px).

**Cas de test :**
- CT-5.1.1 : Cliquer-glisser avec l'outil Pixelate crée une zone avec pixelisation visible.
- CT-5.1.2 : La zone a un contour pointillé (pas continu).
- CT-5.1.3 : Le hit test fonctionne normalement (bounds + tolérance).
- CT-5.1.4 : La zone peut être déplacée et redimensionnée.
- CT-5.1.5 : La copie crée une zone indépendante avec le même pixelSize.
- CT-5.1.6 : Changer pixelSize via le popup toolbar met à jour la pixelisation en temps réel.
- CT-5.1.7 : Le rendu final (`renderFinalImage`) inclut la pixelisation effective.
- CT-5.1.8 : Sans image de fond, le placeholder (grille) est affiché sans crash.

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
- Nom suggéré : nom du fichier source (sans extension) ou `Annoté YYYY-MM-DD à HH.mm.ss`.
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

Le style courant (`canvasView.currentStyle`) est appliqué à chaque nouvelle annotation au moment de sa création. Modifier le style courant via la toolbar n'affecte pas les annotations existantes, sauf si une annotation est sélectionnée (édition live — voir section 2.4).

Les valeurs initiales de `strokeColor`, `fillColor` et `strokeWidth` sont chargées depuis `Preferences` au démarrage.

**Cas de test :**
- CT-10.1 : Une annotation créée utilise le style courant du canvas au moment de la création.
- CT-10.2 : Modifier le style courant après création ne change pas les annotations existantes (sans sélection).
- CT-10.3 : Chaque annotation a sa propre copie du style (pas de partage par référence).
- CT-10.4 : Les couleurs avec alpha (ex: rouge à 50% d'opacité) sont correctement préservées lors de la création et du rendu.
- CT-10.5 : Modifier le style d'une annotation sélectionnée via la toolbar met à jour immédiatement son rendu.
