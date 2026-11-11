import SwiftUI

@main
struct APEXApp: App {
    @StateObject private var health = HealthKitManager.shared
    @StateObject private var router = ApexNavigationRouter.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onAppear {
                    if health.isAvailable {
                        health.fetchLiveHealthMetrics()
                    }
                    if #available(iOS 16.0, *) {
                        ApexShortcutsProvider.updateAppShortcutParameters()
                    }
                }
                .onOpenURL { url in
                    router.openURL(url)
                }
        }
    }
}
