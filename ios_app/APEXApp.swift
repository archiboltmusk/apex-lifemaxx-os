import SwiftUI

@main
struct APEXApp: App {
    @StateObject private var health = HealthKitManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onAppear {
                    // Refresh live Apple HealthKit metrics silently if previously authorized
                    if health.isAvailable {
                        health.fetchLiveHealthMetrics()
                    }
                }
        }
    }
}
