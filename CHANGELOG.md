# Changelog

## [Unreleased] — 2026-08-19

### Ajouté
- **File réseau persistante iPhone → serveur** (`PayloadQueue`) : bilans `workout_completed` en échec écrits sur disque, retry automatique avec backoff exponentiel (5 s → 15 min), survie au redémarrage, compteur + bouton « Réessayer » sur le tableau de bord. Seuls les bilans sont conservés (les métriques live sont éphémères).
- `NSAllowsLocalNetworking` (ATS) pour autoriser les endpoints HTTP locaux.
- Hooks de test DEBUG côté iPhone : `HE_ENDPOINT` (force l’endpoint) et `HE_TEST_PAYLOAD=1` (expédie un bilan de test au démarrage).

- Logs console `[HE]` (Watch) et `[HE-iOS]` (iPhone) : demande d’autorisation, démarrage/arrêt de séance, envois, réceptions, expédition webhook.
- Affichage des erreurs et du statut d’envoi directement sur l’écran de la Watch (`WatchRootView`) — fini les échecs silencieux.
- Log d’activation `WCSession` côté iPhone (état, appairage, joignabilité).
- Contournement DEBUG `HE_DIRECT_HTTP=1` : la Watch expédie le bilan directement au webhook (WatchConnectivity ne fonctionne pas entre simulateurs).

### Corrigé
- Un itinéraire GPS vide (`HKWorkoutRouteBuilder.finishRoute`) ne bloque plus l’envoi du bilan de fin de séance.
- Layout Watch : tuiles qui se chevauchaient, espacements irréguliers (commit précédent, validé en simulateur).

### Validé en simulateur
- Chaîne E2E : autorisation HealthKit → séance auto 45 s (`HE_AUTO_WORKOUT=1`) → 141 points de métriques + GPS simulé (fourni à l’iPhone apparié) → webhook Home Assistant **HTTP 200**.

### Connu / non résolu
- WatchConnectivity inopérant entre simulateurs (limitation Apple) → à valider sur appareils réels.
- `finishRoute` échoue en simulateur (« No data was added to the workout route ») — toléré, GPX reconstruit depuis la série temporelle.
- Feuille d’autorisation HealthKit tronquée sur simulateur Watch 46 mm (bouton « Autoriser » accessible après scroll).
