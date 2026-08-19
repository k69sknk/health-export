import SwiftUI

@main
struct HealthExportWatchApp: App {
    @StateObject private var recorder = WorkoutRecorder()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(recorder)
        }
    }
}
