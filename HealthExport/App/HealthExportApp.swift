import SwiftUI

@main
struct HealthExportApp: App {
    @StateObject private var bridge = GatewayStore()
    @StateObject private var settings = PipelineSettingsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(bridge)
                .environmentObject(settings)
                .preferredColorScheme(.dark)
        }
    }
}
