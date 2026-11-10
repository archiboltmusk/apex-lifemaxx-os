import SwiftUI

@main
struct APEXApp: App {
    @StateObject private var health = HealthKitManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onAppear {
                    health.requestAuthorization()
                }
        }
    }
}
