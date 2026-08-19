import Foundation
import HealthKit
import CoreLocation
import WatchConnectivity

@MainActor
final class WorkoutRecorder: NSObject, ObservableObject {
    @Published var state: HKWorkoutSessionState = .notStarted
    @Published var heartRate: Double?
    @Published var distanceMeters: Double?
    @Published var activeCalories: Double?
    @Published var lastError: String?
    @Published var buffered = 0
    @Published var settings = SettingsStore.load()
    @Published var lastSent = "En attente"

    let workoutId = UUID().uuidString

    private let health = HKHealthStore()
    private let location = CLLocationManager()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var routeBuilder: HKWorkoutRouteBuilder?
    private var sessionDate = Date()
    private var timeSeries: [LiveMetricsEnvelope] = []
    private var routePoints: [GeoPoint] = []
    private var pending: [Data] = []
    private var cadence: Double?
    private var stride: Double?
    private var oscillation: Double?
    private var contact: Double?
    private var power: Double?
    private var watchSession: WCSession?
    private var userId = "runner"

    override init() {
        super.init()
        location.delegate = self
        location.desiredAccuracy = kCLLocationAccuracyBest
        location.activityType = .fitness
        location.distanceFilter = kCLDistanceFilterNone
        if WCSession.isSupported() {
            watchSession = WCSession.default
            watchSession?.delegate = self
            watchSession?.activate()
        }
    }

    func requestAccess() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[HE] HealthKit indisponible sur cet appareil")
            lastError = "HealthKit indisponible"
            return
        }

        var share: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]
        var read: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]

        let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
            .heartRate,
            .distanceWalkingRunning,
            .activeEnergyBurned,
            .runningSpeed,
            .runningPower,
            .runningStrideLength,
            .runningVerticalOscillation,
            .runningGroundContactTime,
            .stepCount
        ]
        for id in quantityIdentifiers {
            if let type = HKQuantityType.quantityType(forIdentifier: id) {
                share.insert(type)
                read.insert(type)
            }
        }

        do {
            print("[HE] Demande d'autorisation HealthKit…")
            try await health.requestAuthorization(toShare: share, read: read)
            print("[HE] Autorisation HealthKit terminée")
            location.requestWhenInUseAuthorization()
        } catch {
            print("[HE] Échec autorisation HealthKit: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }

    func start() async {
        await requestAccess()
        lastError = nil
        sessionDate = Date()

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor

        do {
            let workoutSession = try HKWorkoutSession(healthStore: health, configuration: configuration)
            let workoutBuilder = workoutSession.associatedWorkoutBuilder()
            workoutBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: health, workoutConfiguration: configuration)
            workoutSession.delegate = self
            workoutBuilder.delegate = self

            session = workoutSession
            builder = workoutBuilder

            routeBuilder = HKWorkoutRouteBuilder(healthStore: health, device: nil)
            location.startUpdatingLocation()

            workoutSession.startActivity(with: sessionDate)
            try await workoutBuilder.beginCollection(at: sessionDate)
            state = .running
            print("[HE] Séance démarrée (\(workoutId))")
            sendStarted()
        } catch {
            print("[HE] Échec démarrage séance: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }

    func stop() async {
        print("[HE] Arrêt de la séance…")
        location.stopUpdatingLocation()
        session?.end()
        state = .ended

        guard let builder else { return }
        do {
            try await builder.endCollection(at: Date())
            if let workout = try await builder.finishWorkout() {
                // Un itinéraire vide ne doit pas empêcher l'envoi du bilan.
                if let routeBuilder {
                    do {
                        try await routeBuilder.finishRoute(with: workout, metadata: nil)
                    } catch {
                        print("[HE] Itinéraire non enregistré: \(error.localizedDescription)")
                    }
                }
                let payload = completedPayload()
                pending.append(contentsOf: [try JSONCoding.compactEncoder.encode(payload)])
                print("[HE] Payload final prêt (\(timeSeries.count) points, \(routePoints.count) GPS)")
                flush()

                #if DEBUG
                // Secours simulateur : WatchConnectivity ne fonctionne pas entre
                // simulateurs, on expédie le bilan directement au webhook.
                if ProcessInfo.processInfo.environment["HE_DIRECT_HTTP"] == "1" {
                    await sendDirect(payload)
                }
                #endif
            }
        } catch {
            print("[HE] Échec clôture séance: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }

    private func sendStarted() {
        let envelope = WorkoutStartedEnvelope(
            event: ConnectivityPacket.workoutStarted.rawValue,
            workoutId: workoutId,
            type: "running",
            startDate: sessionDate,
            userId: settings.userId,
            startLocation: routePoints.last
        )
        if let data = try? JSONCoding.compactEncoder.encode(envelope) {
            pending.insert(data, at: 0)
            flush()
        }
    }

    private func tick() {        let metrics = LiveMetrics(
            heartRate: settings.enabledMetrics.contains(.heartRate) ? heartRate : nil,
            speedMps: settings.enabledMetrics.contains(.speedPace) ? currentSpeed() : nil,
            paceSecPerKm: settings.enabledMetrics.contains(.speedPace) ? currentPace() : nil,
            distanceMeters: settings.enabledMetrics.contains(.speedPace) ? distanceMeters : nil,
            cadenceSpm: settings.enabledMetrics.contains(.cadenceElevation) ? cadence : nil,
            elevationMeters: settings.enabledMetrics.contains(.cadenceElevation) ? nil : nil,
            altitude: settings.enabledMetrics.contains(.gps) ? routePoints.last?.altitude : nil,
            verticalOscillationCm: settings.enabledMetrics.contains(.runningDynamics) ? oscillation : nil,
            groundContactTimeMs: settings.enabledMetrics.contains(.runningDynamics) ? contact : nil,
            strideLengthMeters: settings.enabledMetrics.contains(.runningDynamics) ? stride : nil,
            runningPowerWatts: settings.enabledMetrics.contains(.runningDynamics) ? power : nil,
            location: settings.enabledMetrics.contains(.gps) ? routePoints.last : nil
        )

        let envelope = LiveMetricsEnvelope(
            event: ConnectivityPacket.liveMetrics.rawValue,
            workoutId: workoutId,
            timestamp: Date(),
            userId: settings.userId,
            data: metrics
        )

        timeSeries.append(envelope)
        if let data = try? JSONCoding.compactEncoder.encode(envelope) {
            pending.append(data)
        }
        buffered = pending.count
        flush()
    }

    private func completedPayload() -> WorkoutCompletedEnvelope {
        WorkoutCompletedEnvelope(
            event: ConnectivityPacket.workoutCompleted.rawValue,
            workoutId: workoutId,
            type: "running",
            startDate: sessionDate,
            endDate: Date(),
            summary: WorkoutSummary(
                totalDistanceM: distanceMeters ?? 0,
                durationSeconds: Date().timeIntervalSince(sessionDate),
                avgHeartRate: nil,
                maxHeartRate: nil,
                activeCalories: activeCalories,
                elevationAscendedM: nil
            ),
            timeSeries: timeSeries,
            gpxRoute: GPXBuilder.make(name: "Course \(sessionDate.formatted(date: .abbreviated, time: .shortened))", points: routePoints)
        )
    }

    private func flush() {
        guard let session = watchSession, !pending.isEmpty else { return }
        buffered = pending.count

        if session.isReachable {
            let data = pending.removeFirst()
            print("[HE] Envoi paquet → iPhone (\(data.count) o)")
            session.sendMessageData(data) { [weak self] _ in
                Task { @MainActor in
                    self?.lastSent = "Watch → iPhone"
                    self?.flush()
                }
            } errorHandler: { [weak self] error in
                guard let self else { return }
                print("[HE] Échec envoi direct (\(error.localizedDescription)), bascule tampon")
                session.transferUserInfo(["payload": data])
                self.lastSent = "Tampon → iPhone"
                self.flush()
            }
        } else {
            while !pending.isEmpty {
                let data = pending.removeFirst()
                session.transferUserInfo(["payload": data])
            }
            buffered = 0
            lastSent = "Tampon local → iPhone dès retour"
        }
    }

    #if DEBUG
    private func sendDirect(_ payload: WorkoutCompletedEnvelope) async {
        guard let url = URL(string: settings.endpoint), !settings.endpoint.isEmpty else {
            print("[HE] HE_DIRECT_HTTP actif mais endpoint vide")
            return
        }
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONCoding.compactEncoder.encode(payload)
            let (_, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("[HE] Envoi direct webhook → HTTP \(code)")
            lastSent = "Direct webhook → \(code)"
        } catch {
            print("[HE] Échec envoi direct: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }
    #endif

    private func currentSpeed() -> Double? {
        if let value = latest(.runningSpeed) { return value }
        return routePoints.last?.speedMps
    }

    private func currentPace() -> Double? {
        guard let speed = currentSpeed(), speed > 0 else { return nil }
        return 1000 / speed
    }

    private func latest(_ identifier: HKQuantityTypeIdentifier) -> Double? {
        guard
            let type = HKQuantityType.quantityType(forIdentifier: identifier),
            let stats = builder?.statistics(for: type),
            let quantity = stats.mostRecentQuantity()
        else { return nil }

        switch identifier {
        case .heartRate:
            return quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        case .distanceWalkingRunning:
            return quantity.doubleValue(for: .meter())
        case .activeEnergyBurned:
            return quantity.doubleValue(for: .kilocalorie())
        case .runningSpeed:
            return quantity.doubleValue(for: .meter().unitDivided(by: .second()))
        case .runningPower:
            return quantity.doubleValue(for: .watt())
        case .runningStrideLength:
            return quantity.doubleValue(for: .meter())
        case .runningVerticalOscillation:
            return quantity.doubleValue(for: .meterUnit(with: .centi))
        case .runningGroundContactTime:
            return quantity.doubleValue(for: .secondUnit(with: .milli))
        case .stepCount:
            return quantity.doubleValue(for: .count())
        default:
            return nil
        }
    }
}

extension WorkoutRecorder: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            state = toState
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            lastError = error.localizedDescription
        }
    }
}

extension WorkoutRecorder: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            heartRate = latest(.heartRate)
            distanceMeters = latest(.distanceWalkingRunning)
            activeCalories = latest(.activeEnergyBurned)
            power = latest(.runningPower)
            stride = latest(.runningStrideLength)
            oscillation = latest(.runningVerticalOscillation)
            contact = latest(.runningGroundContactTime)

            if let steps = latest(.stepCount), let duration = builder?.elapsedTime, duration > 0 {
                cadence = steps / duration * 60
            }

            tick()
        }
    }
}

extension WorkoutRecorder: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let filtered = locations.filter { $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy <= 65 }
        let points = filtered.map {
            GeoPoint(
                latitude: $0.coordinate.latitude,
                longitude: $0.coordinate.longitude,
                altitude: $0.altitude,
                accuracy: $0.horizontalAccuracy,
                speedMps: $0.speed >= 0 ? $0.speed : nil,
                course: $0.course >= 0 ? $0.course : nil,
                timestamp: $0.timestamp
            )
        }

        Task { @MainActor in
            routePoints.append(contentsOf: points)
            if let routeBuilder {
                try? await routeBuilder.insertRouteData(filtered)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            lastError = error.localizedDescription
        }
    }
}

extension WorkoutRecorder: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["settings"] as? Data,
              let decoded = try? JSONCoding.decoder.decode(PipelineSettings.self, from: data)
        else { return }
        Task { @MainActor in
            settings = decoded
            userId = decoded.userId
        }
    }
}
