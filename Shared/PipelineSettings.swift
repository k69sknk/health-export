import Foundation

struct HeaderPair: Codable, Hashable, Identifiable {
    var id: UUID
    var key: String
    var value: String

    init(id: UUID = UUID(), key: String = "", value: String = "") {
        self.id = id
        self.key = key
        self.value = value
    }
}

enum TransmissionMode: String, Codable, CaseIterable, Identifiable {
    case live
    case batch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .live: return "Temps réel"
        case .batch: return "Fin de course"
        }
    }

    var subtitle: String {
        switch self {
        case .live: return "Flux pendant la séance, dès que l’iPhone est joignable"
        case .batch: return "Un seul envoi à l’arrêt, avec le tracé complet"
        }
    }
}

enum LiveTransport: String, Codable, CaseIterable, Identifiable {
    case websocket
    case sse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .websocket: return "WebSocket"
        case .sse: return "HTTP / SSE"
        }
    }
}

enum BatchFormat: String, Codable, CaseIterable, Identifiable {
    case json
    case gpx
    case fit

    var id: String { rawValue }

    var title: String { rawValue.uppercased() }

    var isReady: Bool { self != .fit }
}

enum StreamMetric: String, Codable, CaseIterable, Identifiable {
    case heartRate
    case gps
    case speedPace
    case cadenceElevation
    case runningDynamics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .heartRate: return "Fréquence cardiaque"
        case .gps: return "Coordonnées GPS"
        case .speedPace: return "Vitesse / allure"
        case .cadenceElevation: return "Cadence & dénivelé"
        case .runningDynamics: return "Dynamique de course"
        }
    }

    var detail: String {
        switch self {
        case .heartRate: return "BPM instantané"
        case .gps: return "Latitude, longitude, altitude, précision"
        case .speedPace: return "m/s, allure, distance cumulée"
        case .cadenceElevation: return "Pas/min et élévation"
        case .runningDynamics: return "Oscillation, contact au sol, foulée, puissance"
        }
    }
}

struct PipelineSettings: Codable, Equatable {
    var mode: TransmissionMode
    var liveTransport: LiveTransport
    var intervalSeconds: Int
    var endpoint: String
    var headers: [HeaderPair]
    var hmacSecret: String
    var userId: String
    var enabledMetrics: Set<StreamMetric>

    static let intervalChoices = [1, 5, 10]

    static let `default` = PipelineSettings(
        mode: .batch,
        liveTransport: .websocket,
        intervalSeconds: 5,
        endpoint: "",
        headers: [],
        hmacSecret: "",
        userId: "runner",
        enabledMetrics: [.heartRate, .gps, .speedPace, .cadenceElevation, .runningDynamics]
    )

    var sanitizedHeaders: [(String, String)] {
        headers
            .map { ($0.key.trimmingCharacters(in: .whitespacesAndNewlines), $0.value) }
            .filter { !$0.0.isEmpty }
    }
}

enum SettingsStore {
    private static let key = "pipeline.settings.v1"

    static func load() -> PipelineSettings {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let value = try? JSONCoding.decoder.decode(PipelineSettings.self, from: data)
        else {
            return .default
        }
        return value
    }

    static func save(_ settings: PipelineSettings) {
        guard let data = try? JSONCoding.compactEncoder.encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
