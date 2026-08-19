import Foundation
import Combine
import SwiftUI

struct ActiveRun {
    var id: String
    var type: String
    var start: Date
    var points: [GeoPoint] = []
}

@MainActor
final class GatewayStore: ObservableObject {
    let gateway = WatchGateway()
    let dispatcher = NetworkDispatcher()

    @Published var settings: PipelineSettings = SettingsStore.load()
    @Published var liveHistory: [LiveMetricsEnvelope] = []
    @Published var completedRuns: [WorkoutCompletedEnvelope] = []
    @Published var activeRun: ActiveRun?
    @Published var lastError: String?

    init() {
        gateway.onStarted = { [weak self] payload in
            self?.handleStarted(payload)
        }
        gateway.onLive = { [weak self] payload in
            self?.handleLive(payload)
        }
        gateway.onCompleted = { [weak self] payload in
            self?.handleCompleted(payload)
        }
    }

    func start() {
        gateway.activate()
    }

    func pushSettings() {
        gateway.pushSettings(settings)
    }

    func sendTestPayload() {
        let now = Date()
        let start = now.addingTimeInterval(-2700)
        let point = GeoPoint(latitude: 47.618, longitude: -0.521, altitude: 42.1, accuracy: 4, speedMps: 3.42, course: 87, timestamp: start)
        let point2 = GeoPoint(latitude: 47.621, longitude: -0.518, altitude: 43.0, accuracy: 4, speedMps: 3.5, course: 91, timestamp: now)

        var series: [LiveMetricsEnvelope] = []
        for i in 0..<5 {
            let metrics = LiveMetrics(
                heartRate: 148 + Double(i * 6),
                speedMps: 3.2 + Double(i) * 0.1,
                paceSecPerKm: 312 - Double(i * 4),
                distanceMeters: 1700 * Double(i + 1),
                cadenceSpm: 170 + Double(i),
                elevationMeters: nil,
                altitude: 42 + Double(i),
                verticalOscillationCm: 7.2,
                groundContactTimeMs: 218,
                strideLengthMeters: 1.1,
                runningPowerWatts: 265,
                location: i.isMultiple(of: 2) ? point : point2
            )
            series.append(LiveMetricsEnvelope(
                event: ConnectivityPacket.liveMetrics.rawValue,
                workoutId: "TEST-\(workoutIdSuffix)",
                timestamp: start.addingTimeInterval(Double(i) * 540),
                userId: settings.userId,
                data: metrics
            ))
        }

        let payload = WorkoutCompletedEnvelope(
            event: ConnectivityPacket.workoutCompleted.rawValue,
            workoutId: "TEST-\(workoutIdSuffix)",
            type: "running",
            startDate: start,
            endDate: now,
            summary: WorkoutSummary(
                totalDistanceM: 8500,
                durationSeconds: 2700,
                avgHeartRate: 152,
                maxHeartRate: 172,
                activeCalories: 620,
                elevationAscendedM: 18
            ),
            timeSeries: series,
            gpxRoute: GPXBuilder.make(name: "Test simulation", points: [point, point2])
        )

        completedRuns.insert(payload, at: 0)
        activeRun = ActiveRun(id: payload.workoutId, type: "running", start: start, points: [point, point2])
        Task {
            do {
                try await dispatcher.sendCompleted(payload, settings: settings)
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    private var workoutIdSuffix: String {
        UUID().uuidString.prefix(8).uppercased().description
    }

    private func handleStarted(_ payload: WorkoutStartedEnvelope) {
        var run = ActiveRun(id: payload.workoutId, type: payload.type, start: payload.startDate)
        if let location = payload.startLocation {
            run.points.append(location)
        }
        activeRun = run
    }

    private func handleLive(_ payload: LiveMetricsEnvelope) {
        liveHistory.append(payload)
        liveHistory = Array(liveHistory.suffix(200))

        if let location = payload.data.location {
            if activeRun?.id == payload.workoutId {
                activeRun?.points.append(location)
            } else if activeRun == nil {
                activeRun = ActiveRun(id: payload.workoutId, type: "running", start: payload.timestamp, points: [location])
            }
        }

        guard settings.mode == .live else { return }
        Task {
            do {
                try await dispatcher.sendLive(payload, settings: settings)
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    private func handleCompleted(_ payload: WorkoutCompletedEnvelope) {
        completedRuns.insert(payload, at: 0)

        if activeRun?.id == payload.workoutId {
            let known = Set(activeRun?.points.map { $0.timestamp } ?? [])
            let extra = payload.timeSeries.compactMap(\.data.location).filter { !known.contains($0.timestamp) }
            activeRun?.points.append(contentsOf: extra)
            activeRun?.points.sort { $0.timestamp < $1.timestamp }
        }

        guard settings.mode == .batch else { return }
        Task {
            do {
                try await dispatcher.sendCompleted(payload, settings: settings)
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
        }
    }
}
