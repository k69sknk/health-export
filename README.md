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
- [x] Testé en simulateur : paire iPhone 16 Pro + Watch Series 10 appairée, `WCSession` joignable, webhook Home Assistant validé (HTTP 200)

### Hot reload (Inject / InjectionNext)

Le hot reload SwiftUI est configuré avec [Inject](https://github.com/krzysztofzablocki/Inject) + [InjectionLite](https://github.com/johnno1962/InjectionLite) et l’app macOS **InjectionNext** :

1. Lancer `InjectionNext.app` (installée dans `/Applications`)
2. Lancer l’app dans le simulateur (le schème `HealthExport` porte `INJECTION_PROJECT_ROOT=$(SRCROOT)`)
3. Modifier une vue, **Cmd+S** → rechargement instantané, sans rebuild

Détails d’implémentation (Debug uniquement) : flags `-Xlinker -interposable -ObjC -weak_framework XCTest`, référence explicite `InjectionLite()` dans `HealthExportApp.swift` (sinon le linker élimine le package statique), vues instrumentées avec `@ObserveInjection` + `.enableInjection()`. Injection n’est pas disponible sur watchOS.

Limites : corps de fonctions et vues seulement ; toute modification de signatures ou de propriétés stockées demande un rebuild.

### Reste à faire

- [ ] Corriger le layout de l’écran Watch (chevauchements sur les tuiles)
- [ ] File réseau persistante iPhone → serveur (retry + backoff si injoignable)
- [ ] Partage live entre abonnés : notifications à l’arrivée d’une séance (MVP possible via automations Home Assistant ; sinon serveur + APNs/Firebase)
- [ ] Export FIT (actuellement placeholder dans les réglages)
- [ ] Export auto Strava / Intervals.icu en fin de course
- [ ] Intervalle d’envoi adaptatif (économie de batterie)
- [ ] Splits automatiques par km
- [ ] Sortir l’URL du webhook du code (config non versionnée)
- [ ] Tests sur appareils réels + validation App Store (HealthKit review)

## Build

```bash
xcodegen generate
xcodebuild -project HealthExport.xcodeproj -scheme HealthExport -destination 'platform=iOS Simulator' build
```

Les payloads JSON sont documentés dans `Shared/WorkoutPayloads.swift` (`LiveMetricsEnvelope`, `WorkoutCompletedEnvelope`, `WorkoutStartedEnvelope`).
