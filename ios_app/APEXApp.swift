import SwiftUI

@main
struct APEXApp: App {
    @StateObject private var health = HealthKitManager.shared
    @StateObject private var router = ApexNavigationRouter.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("apex_has_completed_onboarding") private var hasCompletedOnboarding: Bool = false
    @State private var showOnboardingSheet: Bool = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onAppear {
                    _ = ApexWatchConnectivity.shared
                    _ = ApexStoreManager.shared
                    if health.isAvailable {
                        health.fetchLiveHealthMetrics()
                    }
                    drainPendingWidgetActions()
                    if #available(iOS 16.0, *) {
                        ApexShortcutsProvider.updateAppShortcutParameters()
                    }
                    if !hasCompletedOnboarding {
                        showOnboardingSheet = true
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        drainPendingWidgetActions()
                        ApexWatchConnectivity.shared.pushTelemetryToWatch(health: health)
                    }
                }
                .onOpenURL { url in
                    router.openURL(url)
                }
                .sheet(isPresented: $showOnboardingSheet) {
                    CalibrationOnboardingSheet()
                }
        }
    }

    @MainActor
    private func drainPendingWidgetActions() {
        let pendingWater = ApexSnapshotStore.consumePendingHydrationMl()
        if pendingWater > 0 {
            NutritionLogStore.shared.addWater(ml: pendingWater, health: health)
        }
        let pendingTags = ApexSnapshotStore.consumePendingJournalTags()
        if !pendingTags.isEmpty {
            let store = ExperimentLabStore.shared
            for tagId in pendingTags where !store.dailyTagsToday.contains(tagId) {
                store.toggleJournalTag(tagId)
            }
        }
    }
}
