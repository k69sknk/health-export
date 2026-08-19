import SwiftUI
#if DEBUG
import Inject
#endif

struct DashboardView: View {
    #if DEBUG
    @ObserveInjection private var inject
    #endif
    @EnvironmentObject private var bridge: GatewayStore
    @EnvironmentObject private var settingsStore: PipelineSettingsStore

    private var latest: LiveMetricsEnvelope? { bridge.liveHistory.last }
    private var lastRun: WorkoutCompletedEnvelope? { bridge.completedRuns.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    watchPane
                    if let run = bridge.activeRun, !run.points.isEmpty {
                        LiveMapView(run: run)
                    }
                    streamPane
                    runPane
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .scrollIndicators(.hidden)
            .background(Color.clear)
            .navigationTitle("Passerelle")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Palette.void, for: .navigationBar)
        }
        #if DEBUG
        .enableInjection()
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Health Export")
                .font(Typeface.display(36))
                .foregroundStyle(Palette.paper)
            Text("La Watch capte. L’iPhone relaie. Votre serveur reçoit.")
                .font(Typeface.body(16))
                .foregroundStyle(Palette.paperDim)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Palette.moss.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Palette.paper.opacity(0.08), lineWidth: 1)
        )
    }

    private var watchPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Apple Watch", systemImage: "applewatch")
                    .font(Typeface.body(15, weight: .semibold))
                    .foregroundStyle(Palette.paper)
                Spacer()
                statusPill(title: bridge.gateway.isReachable ? "Joignable" : "Hors portée", tint: bridge.gateway.isReachable ? Palette.chartreuse : Palette.rust)
            }
            Text("Appareil : \(bridge.gateway.isPaired ? "couplé" : "non couplé") · App Watch : \(bridge.gateway.isWatchAppInstalled ? "installée" : "absente")")
                .font(Typeface.body(14))
                .foregroundStyle(Palette.paperDim)
            Text(bridge.gateway.lastPacketSummary)
                .font(Typeface.numeric(15, weight: .medium))
                .foregroundStyle(Palette.paper)
            if let at = bridge.gateway.lastPacketAt {
                Text("Dernier paquet · \(at.formatted(date: .abbreviated, time: .standard))")
                    .font(Typeface.body(13))
                    .foregroundStyle(Palette.paperDim)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Palette.bark.opacity(0.62))
        )
    }

    private var streamPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Flux sortant", systemImage: "arrow.up.forward.app")
                    .font(Typeface.body(15, weight: .semibold))
                    .foregroundStyle(Palette.paper)
                Spacer()
                statusPill(title: settingsStore.settings.mode.title, tint: Palette.celadon)
            }

            Grid(horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    metricTile(title: "BPM", value: latest?.data.heartRate.map { "\(Int($0))" } ?? "—")
                    metricTile(title: "Vitesse", value: latest?.data.speedMps.map { String(format: "%.2f m/s", $0) } ?? "—")
                }
                GridRow {
                    metricTile(title: "Distance", value: latest?.data.distanceMeters.map { String(format: "%.2f km", $0 / 1000) } ?? "—")
                    metricTile(title: "Cadence", value: latest?.data.cadenceSpm.map { "\(Int($0)) /min" } ?? "—")
                }
            }

            if let error = bridge.lastError {
                Text(error)
                    .font(Typeface.body(13))
                    .foregroundStyle(Palette.rust)
            } else {
                Text(settingsStore.canSend ? "Prêt à envoyer vers \(settingsStore.settings.endpoint)" : "Ajoutez l’URL du serveur dans Réglages.")
                    .font(Typeface.body(13))
                    .foregroundStyle(Palette.paperDim)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }

            if bridge.queuedCount > 0 {
                HStack(spacing: 10) {
                    Label("\(bridge.queuedCount) en file", systemImage: "tray.full.fill")
                        .font(Typeface.body(13, weight: .semibold))
                        .foregroundStyle(Palette.chartreuse)
                    if let next = bridge.queue.nextAttemptAt {
                        Text("prochain essai \(next.formatted(date: .omitted, time: .standard))")
                            .font(Typeface.body(12))
                            .foregroundStyle(Palette.paperDim)
                    }
                    Spacer()
                    Button("Réessayer") { bridge.retryNow() }
                        .font(Typeface.body(12, weight: .semibold))
                        .buttonStyle(.bordered)
                        .tint(Palette.chartreuse)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Palette.moss.opacity(0.7))
        )
    }

    private var runPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Dernière course reçue", systemImage: "figure.run")
                .font(Typeface.body(15, weight: .semibold))
                .foregroundStyle(Palette.paper)

            if let run = lastRun {
                HStack(spacing: 12) {
                    metricTile(title: "Distance", value: String(format: "%.2f km", run.summary.totalDistanceM / 1000))
                    metricTile(title: "Durée", value: duration(run.summary.durationSeconds))
                }
                HStack(spacing: 12) {
                    metricTile(title: "FC moy.", value: run.summary.avgHeartRate.map { "\(Int($0))" } ?? "—")
                    metricTile(title: "GPX", value: run.gpxRoute == nil ? "—" : "prêt")
                }
            } else {
                Text("Aucune course terminée n’est encore arrivée de la Watch.")
                    .font(Typeface.body(14))
                    .foregroundStyle(Palette.paperDim)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Palette.bark.opacity(0.62))
        )
    }

    private func metricTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(Typeface.body(11, weight: .semibold))
                .foregroundStyle(Palette.paperDim)
                .tracking(1.2)
            Text(value)
                .font(Typeface.numeric(22, weight: .bold))
                .foregroundStyle(Palette.paper)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.void.opacity(0.5))
        )
    }

    private func statusPill(title: String, tint: Color) -> some View {
        Text(title)
            .font(Typeface.body(12, weight: .semibold))
            .foregroundStyle(Palette.void)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(tint))
    }

    private func duration(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "—"
    }
}
