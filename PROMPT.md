## Mission

Tu es un agent de qualité pour GreenshotMac. Ton objectif : aligner le comportement
des annotations existantes avec l'implémentation originale de Greenshot Windows.

### Ressources disponibles

- **Code source Windows (C#)** : `windows-source/src/` — c'est la référence
- **Code source macOS (Swift)** : `Sources/GreenshotMac/` — c'est ce que tu améliores
- **Spécification** : `SPEC.md` — à mettre à jour avec les écarts découverts
- **Tests existants** : `Tests/GreenshotMacTests/` — à enrichir
- **Journal de suivi** : `COMPARISON_LOG.md` — ta mémoire entre itérations

### Annotations à comparer

| Annotation | C# (windows-source/) | Swift |
|---|---|---|
| Arrow | Drawing/ArrowContainer.cs | Annotations/ArrowAnnotation.swift |
| Text | Drawing/TextContainer.cs | Annotations/TextAnnotation.swift |
| SpeechBubble | Drawing/SpeechbubbleContainer.cs | Annotations/SpeechBubbleAnnotation.swift |
| Rectangle | Drawing/RectangleContainer.cs | Annotations/RectangleAnnotation.swift |
| Ellipse | Drawing/EllipseContainer.cs | Annotations/EllipseAnnotation.swift |
| Line | Drawing/LineContainer.cs | Annotations/LineAnnotation.swift |
| StepLabel | Drawing/StepLabelContainer.cs | Annotations/StepLabelAnnotation.swift |
| Pixelate | Drawing/Filters/PixelizationFilter.cs | Filters/PixelateFilter.swift |
| Highlight | Drawing/Filters/HighlightFilter.cs | Filters/HighlightFilter.swift |
| Crop | Drawing/CropContainer.cs | CropTool.swift |
| Shadow | (intégré dans les containers) | Annotations/ShadowStyle.swift |

### À chaque itération

1. **Consulte `COMPARISON_LOG.md`** pour savoir ce qui a déjà été fait
2. **Choisis** la prochaine annotation ou le prochain écart à traiter
   — priorise ce qui a le plus d'impact sur la qualité
   — tu peux revenir sur une annotation déjà traitée si tu trouves de nouveaux écarts
   — tu peux regrouper des corrections transversales
3. **Lis le code C#** de l'annotation choisie dans windows-source/
4. **Lis le code Swift** correspondant dans Sources/GreenshotMac/
5. **Compare** : algorithmes, valeurs par défaut, edge cases, comportements visuels
6. **Mets à jour SPEC.md** avec les comportements découverts
7. **Crée ou mets à jour les tests** pour couvrir les écarts identifiés
8. **Implante les corrections** dans le code Swift
9. **Exécute `swift test`** et corrige les échecs jusqu'à ce que tout passe
10. **Mets à jour `COMPARISON_LOG.md`** avec :
    - Annotation(s) comparée(s)
    - Écarts trouvés
    - Corrections apportées
    - Tests ajoutés/modifiés
    - Résultat des tests
11. **Commite** avec un message descriptif

### Règles

- Ne PAS ajouter de nouvelles annotations — seulement améliorer les existantes
- Toujours lire le code C# AVANT de modifier le Swift
- Les tests doivent passer avant de commiter
- Adapter les concepts C#/Windows aux idiomes Swift/AppKit/macOS
  (ex: GDI+ → Core Graphics, System.Drawing → NSBezierPath)
- Si un écart est trop complexe pour une seule itération, note-le dans
  COMPARISON_LOG.md comme "À FAIRE" et passe au suivant

### Complétion

Quand TOUTES les annotations du tableau ont été comparées et que les écarts
significatifs ont été corrigés, output :
<promise>COMPARISON_COMPLETE</promise>

IMPORTANT : N'output cette promesse que si c'est véritablement terminé.
Si des itérations restent et que du travail reste à faire, continue.
