import SwiftUI

public struct ContentView: View {
    @State private var selectedTab: Int = 0

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            SummaryView(selectedTab: $selectedTab)
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

            LongevityView()
                .tabItem {
                    Label("Longevity", systemImage: "hourglass")
                }
                .tag(3)
        }
        .tint(ApexTheme.accentVolt)
        .onChange(of: selectedTab) { _, _ in
            Haptics.tap(.soft)
        }
    }
}
