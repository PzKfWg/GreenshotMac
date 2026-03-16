Build, package et déployer GreenshotMac dans /Applications/.

Étapes à suivre dans l'ordre :

1. **Fermer l'instance en cours** s'il y en a une :
   ```bash
   pkill -x GreenshotMac 2>/dev/null || true
   ```

2. **Builder et déployer** via le script bundle :
   ```bash
   ./scripts/bundle.sh
   ```
   Ce script fait : swift build (release), création du .app bundle, signature ad-hoc, copie dans /Applications/, xattr -cr.

3. **Relancer l'app** :
   ```bash
   open /Applications/GreenshotMac.app
   ```

4. Confirmer à l'utilisateur que le déploiement est terminé avec la sortie du script.

Si le build échoue, afficher les erreurs et ne PAS tenter de relancer l'ancienne version.
