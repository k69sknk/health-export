import Foundation
import WatchConnectivity

protocol PhoneInboxDelegate: AnyObject {
    func phoneDidReceiveLive(_ envelope: LiveMetricsEnvelope)
    func phoneDidReceiveCompleted(_ envelope: WorkoutCompletedEnvelope)
}

final class PhoneConnectivityService: NSObject, WCSessionDelegate {
    static let shared = PhoneConnectivityService()

    weak var inbox: PhoneInboxDelegate?
    private var session: WCSession?

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    func pushSettings(_ settings: PipelineSettings) {
        guard let data = try? JSONCoding.compactEncoder.encode(settings),
              let json = String(data: data, encoding: .utf8)
        else { return }
        try? session?.updateApplicationContext([
            ConnectivityPacket.settingsSync.rawValue: json
        ])
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handle(userInfo)
    }

    private func handle(_ payload: [String: Any]) {
        guard let type = payload["type"] as? String,
              let json = payload["json"] as? String,
              let data = json.data(using: .utf8)
        else { return }

        DispatchQueue.main.async {
            switch type {
            case ConnectivityPacket.liveMetrics.rawValue:
                if let envelope = try? JSONCoding.decoder.decode(LiveMetricsEnvelope.self, from: data) {
                    self.inbox?.phoneDidReceiveLive(envelope)
                }
            case ConnectivityPacket.workoutCompleted.rawValue:
                if let envelope = try? JSONCoding.decoder.decode(WorkoutCompletedEnvelope.self, from: data) {
                    self.inbox?.phoneDidReceiveCompleted(envelope)
                }
            default:
                break
            }
        }
    }
}
