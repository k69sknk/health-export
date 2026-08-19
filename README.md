# Health Export

Passerelle Apple Watch → iPhone → serveur pour exporter les données de course à pied (métriques HealthKit + tracé GPS) en temps réel ou en fin de séance, gratuitement et chez soi.

## Architecture

```
[ Apple Watch ] ──( WatchConnectivity )──> [ iPhone (passerelle) ] ──> [ Serveur ]
  HKWorkoutSession, GPS, cadence…           buffer, relay, carte live    WebSocket / Webhook HTTP
```

- **Watch** (`HealthExportWatch/`) : `HKWorkoutSession` + `HKLiveWorkoutBuilder` + `CLLocationManager` + `HKWorkoutRouteBuilder`. Envoie `workout_started`, puis `live_metrics` en continu, puis `workout_completed` avec série temporelle + GPX. Tampon local si l’iPhone est hors de portée.
- **iPhone** (`HealthExport/`) : reçoit via `WCSession`, affiche le tableau de bord + carte MapKit live, relaie vers le serveur (WebSocket ou HTTP POST, headers personnalisés, signature HMAC-SHA256 optionnelle).
- **Partagé** (`Shared/`) : modèles Codable, réglages, catalogue des champs exportables, builder GPX.

## Avancement

### Fait

- [x] Projet XcodeGen multi-cibles iOS 17 / watchOS 10, compilation iOS + watchOS vérifiée
- [x] Séance de course sur Watch avec métriques live (FC, distance, calories, cadence, dynamique de course)
- [x] Tracé GPS enregistré (Core Location + `HKWorkoutRoute`) et export GPX
- [x] Canal Watch → iPhone avec tampon hors ligne (`sendMessageData` + `transferUserInfo`)
- [x] Événement `workout_started` avec point de départ
- [x] Relais iPhone → serveur : WebSocket (live) et webhook HTTP POST (fin de course), headers custom, HMAC
- [x] Écran de réglages complet (mode, protocole, intervalle, endpoint, headers, secret, métriques)
- [x] Carte MapKit live sur iPhone (polyline, départ, position)
- [x] Bouton « course de test » envoyant un payload complet au webhook
- [x] Catalogue de tout ce qui est exportable (onglet Exports)
- [x] Layout Watch compact refait (plus de chevauchement des tuiles)
- [x] Erreurs et statut d’envoi affichés sur la Watch (plus d’échec silencieux)
- [x] Logs console `[HE]` / `[HE-iOS]` des deux côtés pour le débogage
- [x] Test E2E en simulateur validé : séance auto 45 s → 141 points de métriques + GPS → **webhook Home Assistant HTTP 200**

## Tests en simulateur

Paire dédiée : `HealthExport iPhone` + `HealthExport Watch` (créée appairée).

```bash
# 1. Démarrer la paire (iPhone D'ABORD, sinon la paire reste "disconnected")
xcrun simctl boot <IPHONE_UDID> && xcrun simctl boot <WATCH_UDID>

# 2. GPS simulé : le fournir à l'iPHONE (la Watch simulée hérite de la position
#    du téléphone apparié ; `simctl location` sur la Watch ne fait rien)
xcrun simctl location <IPHONE_UDID> start 47.4736,-0.5517 47.4748,-0.5490 \
  47.4761,-0.5463 47.4774,-0.5436 47.4787,-0.5409 --speed 4

# 3. Lancer l'iPhone (console capturée)
xcrun simctl launch --console-pty <IPHONE_UDID> com.github.k69sknk.healthexport

# 4. Lancer la Watch : séance auto 45 s + envoi direct webhook (secours simu)
SIMCTL_CHILD_HE_AUTO_WORKOUT=1 SIMCTL_CHILD_HE_DIRECT_HTTP=1 \
  xcrun simctl launch --console-pty <WATCH_UDID> com.github.k69sknk.healthexport.watchkitapp
```

Au premier lancement, une feuille HealthKit s’affiche sur la Watch : **faire défiler la feuille vers le haut** pour révéler le bouton « Autoriser » (hors champ initial). L’autorisation est mémorisée ensuite.

### Limites connues du simulateur

- **WatchConnectivity ne fonctionne pas entre deux simulateurs** (`sendMessageData` échoue, `transferUserInfo` jamais livré, `isReachable` incohérent) même avec une paire « connected ». Le lien Watch → iPhone doit être validé **sur appareils réels**. En DEBUG, `HE_DIRECT_HTTP=1` fait expédier le bilan directement au webhook par la Watch pour tester la chaîne malgré tout.
- `HKWorkoutRouteBuilder.finishRoute` échoue avec « No data was added to the workout route » en simulateur — toléré (le tracé est de toute façon dans la série temporelle et le GPX), à revalider sur appareil réel.
- Le GPS simulé n’est actif que si la séance démarre pendant la fenêtre de simulation (redémarrer `simctl location` avant chaque run).

### Hot reload (Inject / InjectionNext)

Le hot reload SwiftUI est configuré avec [Inject](https://github.com/krzysztofzablocki/Inject) + [InjectionLite](https://github.com/johnno1962/InjectionLite) et l’app macOS **InjectionNext** :

1. Lancer `InjectionNext.app` (installée dans `/Applications`)
2. Lancer l’app dans le simulateur (le schème `HealthExport` porte `INJECTION_PROJECT_ROOT=$(SRCROOT)`)
3. Modifier une vue, **Cmd+S** → rechargement instantané, sans rebuild

Détails d’implémentation (Debug uniquement) : flags `-Xlinker -interposable -ObjC -weak_framework XCTest`, référence explicite `InjectionLite()` dans `HealthExportApp.swift` (sinon le linker élimine le package statique), vues instrumentées avec `@ObserveInjection` + `.enableInjection()`. Injection n’est pas disponible sur watchOS.

Limites : corps de fonctions et vues seulement ; toute modification de signatures ou de propriétés stockées demande un rebuild.

### Reste à faire

- [ ] **Valider WatchConnectivity sur appareils réels** (bloquant — non testable en simulateur) + signature/provisioning
- [ ] File réseau persistante iPhone → serveur (retry + backoff si injoignable)
- [ ] Partage live entre abonnés : notifications à l’arrivée d’une séance (MVP possible via automations Home Assistant ; sinon serveur + APNs/Firebase)
- [ ] Export FIT (actuellement placeholder dans les réglages)
- [ ] Export auto Strava / Intervals.icu en fin de course
- [ ] Intervalle d’envoi adaptatif (économie de batterie)
- [ ] Splits automatiques par km
- [ ] Sortir l’URL du webhook du code (config non versionnée)
- [ ] Validation App Store (HealthKit review)

### À revoir

- **URL du webhook Home Assistant en clair** dans `Shared/PipelineSettings.swift` (valeur par défaut versionnée) — à externaliser avant toute mise en publique du dépôt.
- `HKWorkoutRouteBuilder` vide en simulateur : vérifier sur appareil réel que `insertRouteData` alimente bien la route (les `try?` masquent les erreurs).
- Feuille d’autorisation HealthKit tronquée sur Watch 46 mm simulée (bouton « Autoriser » hors champ, nécessite un scroll) — vérifier le comportement sur vraie Watch.
- Le tampon Watch (`transferUserInfo`) n’a pas pu être validé en simulateur ; tester le scénario « iPhone éteint pendant la course » sur matériel réel.
- Le contournement `HE_DIRECT_HTTP` est DEBUG-only : ne pas l’activer dans un schéma de release.

## Build

```bash
xcodegen generate
xcodebuild -project HealthExport.xcodeproj -scheme HealthExport -destination 'platform=iOS Simulator' build
```

Les payloads JSON sont documentés dans `Shared/WorkoutPayloads.swift` (`LiveMetricsEnvelope`, `WorkoutCompletedEnvelope`, `WorkoutStartedEnvelope`).
