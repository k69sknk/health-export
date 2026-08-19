import SwiftUI
import HealthKit

struct WatchRootView: View {
    @EnvironmentObject private var recorder: WorkoutRecorder

    var body: some View {
        VStack(spacing: 8) {
            header
            primaryMetrics
            secondaryMetrics
            statusLine
            actionButton
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.void)
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.environment["HE_AUTO_WORKOUT"] == "1" {
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    await recorder.start()
                    try? await Task.sleep(for: .seconds(45))
                    await recorder.stop()
                }
            }
            #endif
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(recorder.state == .running ? Palette.chartreuse : Palette.celadon)
                .frame(width: 7, height: 7)
            Text(recorder.state == .running ? "En cours" : "Prêt")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(Palette.paper)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    private var primaryMetrics: some View {
        HStack(spacing: 6) {
            primaryTile(
                title: "BPM",
                value: recorder.heartRate.map { "\(Int($0))" } ?? "—",
                tint: Palette.rust
            )
            primaryTile(
                title: "KM",
                value: recorder.distanceMeters.map { String(format: "%.2f", $0 / 1000) } ?? "—",
                tint: Palette.chartreuse
            )
        }
    }

    private var secondaryMetrics: some View {
        HStack(spacing: 6) {
            secondaryTile(title: "KCAL", value: recorder.activeCalories.map { "\(Int($0))" } ?? "—")
            secondaryTile(title: "BUFFER", value: "\(recorder.buffered)")
        }
    }

    private var statusLine: some View {
        Group {
            if let error = recorder.lastError {
                Text(error)
                    .foregroundStyle(Palette.rust)
            } else {
                Text(recorder.lastSent)
                    .foregroundStyle(Palette.paperDim)
            }
        }
        .font(.system(.caption2, design: .rounded, weight: .medium))
        .lineLimit(2)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private var actionButton: some View {
        Group {
            if recorder.state == .running {
                Button(role: .destructive) {
                    Task { await recorder.stop() }
                } label: {
                    Label("Stop & envoyer", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.rust)
            } else {
                Button {
                    Task { await recorder.start() }
                } label: {
                    Label("Démarrer", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.chartreuse)
            }
        }
        .font(.system(.subheadline, design: .rounded, weight: .semibold))
    }

    private func primaryTile(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(Palette.paperDim)
                .tracking(1)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Palette.bark.opacity(0.55))
        )
    }

    private func secondaryTile(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(Palette.paperDim)
            Spacer(minLength: 4)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(Palette.paper)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Palette.moss.opacity(0.7))
        )
    }
}
