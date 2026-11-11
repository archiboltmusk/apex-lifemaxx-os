import AppIntents
import Foundation

// MARK: - Siri Shortcuts, Spotlight & iPhone Action Button Intents
@available(iOS 16.0, *)
public struct CheckReadinessIntent: AppIntent {
    public static var title: LocalizedStringResource = "Check Autonomic Readiness"
    public static var description = IntentDescription("Opens your APEX Today Summary and speaks your latest Readiness & HRV.")
    public static var openAppWhenRun: Bool = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        ApexNavigationRouter.shared.selectedTab = 0
        HealthKitManager.shared.fetchLiveHealthMetrics()
        if let readiness = HealthKitManager.shared.readinessScore {
            let hrvStr = HealthKitManager.shared.heartRateVariability.map { "\(Int($0.rounded())) ms" } ?? "no HRV sample"
            return .result(dialog: "Your APEX readiness is \(readiness) percent with \(hrvStr).")
        }
        return .result(dialog: "APEX Summary opened. Connect Apple Health to sync readiness.")
    }
}

@available(iOS 16.0, *)
public struct OpenFaceScanIntent: AppIntent {
    public static var title: LocalizedStringResource = "Start Craniofacial Scan"
    public static var description = IntentDescription("Launches APEX Face Scan for symmetry, canthal tilt, and TrueDepth analysis.")
    public static var openAppWhenRun: Bool = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        ApexNavigationRouter.shared.selectedTab = 1
        return .result(dialog: "Opening APEX Face Scan.")
    }
}

@available(iOS 16.0, *)
public struct StartOpticalTrainingIntent: AppIntent {
    public static var title: LocalizedStringResource = "Start Optical Workout"
    public static var description = IntentDescription("Opens APEX Optical Pose Tracking for strength reps and velocity loss.")
    public static var openAppWhenRun: Bool = true

    @Parameter(title: "Exercise", default: "Squats")
    public var exercise: String

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        ApexNavigationRouter.shared.requestedExerciseRaw = exercise
        ApexNavigationRouter.shared.selectedTab = 2
        return .result(dialog: "Ready for \(exercise) in APEX Train.")
    }
}

@available(iOS 16.0, *)
public struct StartDeadHangIntent: AppIntent {
    public static var title: LocalizedStringResource = "Start Dead Hang Timer"
    public static var description = IntentDescription("Opens Longevity and starts the 2-minute centenarian Dead Hang stopwatch.")
    public static var openAppWhenRun: Bool = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        ApexNavigationRouter.shared.shouldAutoStartDeadHang = true
        ApexNavigationRouter.shared.selectedTab = 4
        return .result(dialog: "Starting your Dead Hang endurance timer.")
    }
}

@available(iOS 16.0, *)
public struct ApexShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckReadinessIntent(),
            phrases: [
                "Check readiness in \(.applicationName)",
                "How recovered am I in \(.applicationName)"
            ],
            shortTitle: "Check Readiness",
            systemImageName: "heart.text.square.fill"
        )
        AppShortcut(
            intent: OpenFaceScanIntent(),
            phrases: [
                "Scan my face in \(.applicationName)",
                "Start face scan in \(.applicationName)"
            ],
            shortTitle: "Face Scan",
            systemImageName: "faceid"
        )
        AppShortcut(
            intent: StartOpticalTrainingIntent(),
            phrases: [
                "Start optical workout in \(.applicationName)",
                "Track reps in \(.applicationName)"
            ],
            shortTitle: "Optical Train",
            systemImageName: "figure.strengthtraining.traditional"
        )
        AppShortcut(
            intent: StartDeadHangIntent(),
            phrases: [
                "Start dead hang in \(.applicationName)",
                "Time dead hang in \(.applicationName)"
            ],
            shortTitle: "Dead Hang Timer",
            systemImageName: "hourglass"
        )
    }
}
