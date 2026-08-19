import Foundation
import Combine

@MainActor
final class PipelineSettingsStore: ObservableObject {
    @Published var settings: PipelineSettings {
        didSet { SettingsStore.save(settings) }
    }

    init() {
        settings = SettingsStore.load()
    }

    func addHeader() {
        settings.headers.append(HeaderPair(key: "", value: ""))
    }

    func removeHeader(_ header: HeaderPair) {
        settings.headers.removeAll { $0.id == header.id }
    }

    var canSend: Bool {
        !settings.endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
