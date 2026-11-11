import SwiftUI

public struct ContentView: View {
    @ObservedObject private var router = ApexNavigationRouter.shared

    public init() {}

    public var body: some View {
        TabView(selection: $router.selectedTab) {
            SummaryView(selectedTab: $router.selectedTab)
                .tabItem {
                    Label("Summary", systemImage: "heart.text.square.fill")
                }
                .tag(0)

            FaceScanView()
                .tabItem {
                    Label("Face", systemImage: "faceid")
                }
                .tag(1)

            CameraWorkoutView()
                .tabItem {
                    Label("Train", systemImage: "figure.strengthtraining.traditional")
                }
                .tag(2)

            NutritionCGMView()
                .tabItem {
                    Label("Fuel", systemImage: "fork.knife")
                }
                .tag(3)

            LongevityView()
                .tabItem {
                    Label("Biology", systemImage: "hourglass")
                }
                .tag(4)
        }
        .tint(ApexTheme.accentVolt)
        .onChange(of: router.selectedTab) { _, _ in
            Haptics.tap(.soft)
        }
    }
}
