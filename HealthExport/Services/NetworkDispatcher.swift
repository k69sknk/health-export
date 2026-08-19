import Foundation
import CryptoKit

@MainActor
final class NetworkDispatcher: ObservableObject {
    @Published var isConnected = false
    @Published var lastError: String?

    private var webSocketTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)

    func sendLive(_ payload: LiveMetricsEnvelope, settings: PipelineSettings) async throws {
        let data = try JSONCoding.compactEncoder.encode(payload)
        switch settings.liveTransport {
        case .websocket:
            try await sendOverWebSocket(data: data, settings: settings)
        case .sse:
            try await sendOverHTTP(data: data, settings: settings)
        }
    }

    func sendCompleted(_ payload: WorkoutCompletedEnvelope, settings: PipelineSettings) async throws {
        let data = try JSONCoding.compactEncoder.encode(payload)
        try await sendOverHTTP(data: data, settings: settings)
    }

    private func sendOverWebSocket(data: Data, settings: PipelineSettings) async throws {
        guard let url = URL(string: settings.endpoint), url.scheme?.hasPrefix("ws") == true else {
            throw DispatcherError.invalidEndpoint("Entrez une URL ws:// ou wss:// pour le temps réel.")
        }

        if webSocketTask == nil {
            var request = URLRequest(url: url)
            settings.sanitizedHeaders.forEach { request.addValue($1, forHTTPHeaderField: $0) }
            let task = session.webSocketTask(with: request)
            task.resume()
            webSocketTask = task
            isConnected = true
        }

        try await webSocketTask?.send(.data(data))
    }

    private func sendOverHTTP(data: Data, settings: PipelineSettings) async throws {
        guard let url = URL(string: settings.endpoint) else {
            throw DispatcherError.invalidEndpoint("Entrez l’URL du webhook ou du flux HTTP.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        settings.sanitizedHeaders.forEach { request.addValue($1, forHTTPHeaderField: $0) }

        let secret = settings.hmacSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        if !secret.isEmpty {
            let signature = HMAC<SHA256>.authenticationCode(for: data, using: SymmetricKey(data: Data(secret.utf8)))
            request.setValue(Data(signature).map { String(format: "%02x", $0) }.joined(), forHTTPHeaderField: "X-Signature")
        }

        request.httpBody = data
        let (_, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw DispatcherError.serverStatus(http.statusCode)
        }
        isConnected = true
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }
}

enum DispatcherError: LocalizedError {
    case invalidEndpoint(String)
    case serverStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint(let message): return message
        case .serverStatus(let code): return "Le serveur a répondu \(code)."
        }
    }
}
