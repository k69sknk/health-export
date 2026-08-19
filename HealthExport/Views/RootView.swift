import SwiftUI

struct RootView: View {
    @EnvironmentObject private var bridge: GatewayStore
    @EnvironmentObject private var settingsStore: PipelineSettingsStore

    var body: some View {
        ZStack {
            Palette.void.ignoresSafeArea()
            GrainOverlay().ignoresSafeArea().allowsHitTesting(false)

            TabView {
                DashboardView()
                    .tabItem { Label("Tableau", systemImage: "waveform.path.ecg") }
                SettingsView()
                    .tabItem { Label("Réglages", systemImage: "slider.horizontal.3") }
                CatalogView()
                    .tabItem { Label("Exports", systemImage: "shippingbox") }
            }
            .tint(Palette.chartreuse)
        }
        .onAppear {
            bridge.settings = settingsStore.settings
            bridge.start()
        }
        .onChange(of: settingsStore.settings) { _, newValue in
            bridge.settings = newValue
            bridge.pushSettings()
        }
    }
}

struct GrainOverlay: View {
    var body: some View {
        Canvas { context, size in
            for _ in 0..<900 {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let alpha = Double.random(in: 0.015...0.05)
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 1.2, height: 1.2)),
                    with: .color(.white.opacity(alpha))
                )
            }
        }
        .opacity(0.35)
        .blendMode(.overlay)
    }
}
