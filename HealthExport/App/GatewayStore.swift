import Foundation
import Combine
import SwiftUI

@MainActor
final class GatewayStore: ObservableObject {
    let gateway = WatchGateway()
    let dispatcher = NetworkDispatcher()

    @Published var settings: PipelineSettings = SettingsStore.load()
    @Published var liveHistory: [LiveMetricsEnvelope] = []
    @Published var completedRuns: [WorkoutCompletedEnvelope] = []
    @Published var lastError: String?

    init() {
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

    private func handleLive(_ payload: LiveMetricsEnvelope) {
        liveHistory.append(payload)
        liveHistory = Array(liveHistory.suffix(200))
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
