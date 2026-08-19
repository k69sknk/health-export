import SwiftUI
import HealthKit

struct WatchRootView: View {
    @EnvironmentObject private var recorder: WorkoutRecorder

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Health Export")
                    .font(Typeface.display(26))
                    .foregroundStyle(Palette.paper)

                Text(recorder.state == .running ? "Course en cours" : "Prêt")
                    .font(Typeface.body(13, weight: .semibold))
                    .foregroundStyle(Palette.celadon)

                HStack(spacing: 10) {
                    tile(title: "BPM", value: recorder.heartRate.map { "\(Int($0))" } ?? "—")
                    tile(title: "KM", value: recorder.distanceMeters.map { String(format: "%.2f", $0 / 1000) } ?? "—")
                }
                HStack(spacing: 10) {
                    tile(title: "Cadence", value: recorder.distanceMeters == nil ? "—" : "auto")
                    tile(title: "Tampon", value: "\(recorder.buffered)")
                }

                if recorder.state == .running {
                    Button(role: .destructive) {
                        Task { await recorder.stop() }
                    } label: {
                        Label("Stop & envoyer", systemImage: "stop.circle")
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        Task { await recorder.start() }
                    } label: {
                        Label("Démarrer la course", systemImage: "play.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.chartreuse)
                }

                if let error = recorder.lastError {
                    Text(error)
                        .font(Typeface.body(12))
                        .foregroundStyle(Palette.rust)
                }
            }
            .padding()
        }
        .background(Palette.void)
    }

    private func tile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(Typeface.body(10, weight: .semibold))
                .foregroundStyle(Palette.paperDim)
            Text(value)
                .font(Typeface.numeric(18, weight: .bold))
                .foregroundStyle(Palette.paper)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.bark.opacity(0.55)))
    }
}
