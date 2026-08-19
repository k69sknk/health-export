import SwiftUI

#if DEBUG
import InjectionLite

// Référence explicite : sans symbole utilisé, l'éditeur de liens
// élimine le package statique et l'injection ne démarre jamais.
private let injectionBootstrap: AnyObject = InjectionLite()
#endif

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
