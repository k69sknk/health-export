import Foundation
import WatchConnectivity

@MainActor
final class WatchGateway: NSObject, ObservableObject, WCSessionDelegate {
    @Published var isReachable = false
    @Published var isSupported = false
    @Published var isPaired = false
    @Published var isWatchAppInstalled = false
    @Published var lastPacketAt: Date?
    @Published var lastPacketSummary = "Aucun paquet"

    private var session: WCSession?
    var onLive: ((LiveMetricsEnvelope) -> Void)?
    var onCompleted: ((WorkoutCompletedEnvelope) -> Void)?

    override init() {
        super.init()
        isSupported = WCSession.isSupported()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        if session == nil {
            session = WCSession.default
            session?.delegate = self
        }
        session?.activate()
    }

    func pushSettings(_ settings: PipelineSettings) {
        guard
            let session,
            let data = try? JSONCoding.compactEncoder.encode(settings)
        else { return }

        do {
            try session.updateApplicationContext(["settings": data])
        } catch {
            lastPacketSummary = "Réglages non synchronisés"
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            isReachable = session.isReachable
            isPaired = session.isPaired
            isWatchAppInstalled = session.isWatchAppInstalled
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isReachable = session.isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        let data = messageData
        Task { @MainActor in
            handle(data: data)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let data = userInfo["payload"] as? Data {
            Task { @MainActor in
                handle(data: data)
            }
        }
    }

    private func handle(data: Data) {
        if let live = try? JSONCoding.decoder.decode(LiveMetricsEnvelope.self, from: data), live.event == ConnectivityPacket.liveMetrics.rawValue {
            Task { @MainActor in
                lastPacketAt = Date()
                lastPacketSummary = "Live · \(live.data.heartRate.map { "\(Int($0)) bpm" } ?? "metrics")"
                onLive?(live)
            }
            return
        }

        if let done = try? JSONCoding.decoder.decode(WorkoutCompletedEnvelope.self, from: data), done.event == ConnectivityPacket.workoutCompleted.rawValue {
            Task { @MainActor in
                lastPacketAt = Date()
                lastPacketSummary = "Fin de course · \(done.timeSeries.count) points"
                onCompleted?(done)
            }
        }
    }
}
