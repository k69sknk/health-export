import Foundation

struct QueuedPayload: Codable, Identifiable {
    var id: UUID
    var createdAt: Date
    var attempts: Int
    var nextAttemptAt: Date
    var data: Data
}

/// File d'attente persistante des bilans de séance en échec d'envoi.
/// Un fichier JSON par payload dans Application Support/payload-queue,
/// avec backoff exponentiel (5 s → 15 min max). Seuls les bilans
/// `workout_completed` sont conservés : les métriques live sont éphémères.
@MainActor
final class PayloadQueue: ObservableObject {
    @Published private(set) var items: [QueuedPayload] = []

    private let directory: URL

    init(directory: URL? = nil) {
        let base = directory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("payload-queue", isDirectory: true)
        self.directory = base
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        load()
    }

    var nextAttemptAt: Date? {
        items.map(\.nextAttemptAt).min()
    }

    func enqueue(_ payload: WorkoutCompletedEnvelope) {
        guard let data = try? JSONCoding.compactEncoder.encode(payload) else { return }
        let item = QueuedPayload(id: UUID(), createdAt: Date(), attempts: 0, nextAttemptAt: Date(), data: data)
        items.append(item)
        persist(item)
        print("[HE-iOS] Bilan mis en file (\(items.count) en attente)")
    }

    func remove(_ item: QueuedPayload) {
        items.removeAll { $0.id == item.id }
        try? FileManager.default.removeItem(at: fileURL(for: item))
    }

    func markFailed(_ item: QueuedPayload) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].attempts += 1
        let delay = min(pow(2.0, Double(items[index].attempts - 1)) * 5, 900)
        items[index].nextAttemptAt = Date().addingTimeInterval(delay)
        persist(items[index])
        print("[HE-iOS] Nouvel essai dans \(Int(delay)) s (tentative \(items[index].attempts))")
    }

    func dueItems(now: Date = Date()) -> [QueuedPayload] {
        items.filter { $0.nextAttemptAt <= now }.sorted { $0.nextAttemptAt < $1.nextAttemptAt }
    }

    private func load() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        items = files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? Data(contentsOf: $0) }
            .compactMap { try? JSONCoding.decoder.decode(QueuedPayload.self, from: $0) }
            .sorted { $0.createdAt < $1.createdAt }
        if !items.isEmpty {
            print("[HE-iOS] File rechargée : \(items.count) bilan(s) en attente")
        }
    }

    private func persist(_ item: QueuedPayload) {
        guard let data = try? JSONCoding.compactEncoder.encode(item) else { return }
        try? data.write(to: fileURL(for: item), options: .atomic)
    }

    private func fileURL(for item: QueuedPayload) -> URL {
        directory.appendingPathComponent("\(item.id.uuidString).json")
    }
}
