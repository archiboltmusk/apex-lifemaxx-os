import Foundation
import ActivityKit

// MARK: - Shared 7-Day & Intraday Telemetry Samples
public struct DailyMetricPoint: Codable, Identifiable, Equatable {
    public var id: Date { date }
    public let date: Date
    public let value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

public struct HourlyMetricPoint: Codable, Identifiable, Equatable {
    public var id: Date { date }
    public let date: Date
    public let value: Double
    public let label: String

    public init(date: Date, value: Double, label: String = "") {
        self.date = date
        self.value = value
        self.label = label
    }
}

// MARK: - Shared WidgetKit Snapshot (Written by Main App, Read by Home & Lock Screen Widgets)
public struct ApexWidgetSnapshot: Codable {
    public var moveCalories: Double
    public var moveTarget: Double
    public var exerciseMinutes: Double
    public var exerciseTarget: Double
    public var standHours: Double
    public var standTarget: Double
    public var readinessScore: Int?
    public var energyBank: Int?
    public var strainScore: Double?
    public var hrv: Double?
    public var hrvDeltaPercent: Int?
    public var restingHR: Double?
    public var sleepHours: Double?
    public var biologicalAge: Double?
    public var clinicalPhenoAge: Double?
    public var deadHangBestSec: Int
    public var dailySteps: Int
    public var updatedAt: Date

    public init(
        moveCalories: Double = 0,
        moveTarget: Double = 750,
        exerciseMinutes: Double = 0,
        exerciseTarget: Double = 30,
        standHours: Double = 0,
        standTarget: Double = 12,
        readinessScore: Int? = nil,
        energyBank: Int? = nil,
        strainScore: Double? = nil,
        hrv: Double? = nil,
        hrvDeltaPercent: Int? = nil,
        restingHR: Double? = nil,
        sleepHours: Double? = nil,
        biologicalAge: Double? = nil,
        clinicalPhenoAge: Double? = nil,
        deadHangBestSec: Int = 0,
        dailySteps: Int = 0,
        updatedAt: Date = Date()
    ) {
        self.moveCalories = moveCalories
        self.moveTarget = moveTarget
        self.exerciseMinutes = exerciseMinutes
        self.exerciseTarget = exerciseTarget
        self.standHours = standHours
        self.standTarget = standTarget
        self.readinessScore = readinessScore
        self.energyBank = energyBank
        self.strainScore = strainScore
        self.hrv = hrv
        self.hrvDeltaPercent = hrvDeltaPercent
        self.restingHR = restingHR
        self.sleepHours = sleepHours
        self.biologicalAge = biologicalAge
        self.clinicalPhenoAge = clinicalPhenoAge
        self.deadHangBestSec = deadHangBestSec
        self.dailySteps = dailySteps
        self.updatedAt = updatedAt
    }
}

public enum ApexSnapshotStore {
    public static let appGroupId = "group.club.apex.lifemaxx"
    private static let key = "apex_widget_snapshot_v1"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupId) ?? .standard
    }

    public static func save(_ snapshot: ApexWidgetSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: key)
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    public static func load() -> ApexWidgetSnapshot {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(ApexWidgetSnapshot.self, from: data) {
            return decoded
        }
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(ApexWidgetSnapshot.self, from: data) {
            return decoded
        }
        return ApexWidgetSnapshot()
    }
}

// MARK: - ActivityKit Live Activity Attributes (Dynamic Island + Lock Screen)
@available(iOS 16.1, *)
public struct ApexWorkoutAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var reps: Int
        public var elapsedSeconds: Int
        public var restSecondsRemaining: Int
        public var isResting: Bool
        public var lastVelocity: Double
        public var velocityDropPercent: Int

        public init(
            reps: Int,
            elapsedSeconds: Int,
            restSecondsRemaining: Int,
            isResting: Bool,
            lastVelocity: Double,
            velocityDropPercent: Int
        ) {
            self.reps = reps
            self.elapsedSeconds = elapsedSeconds
            self.restSecondsRemaining = restSecondsRemaining
            self.isResting = isResting
            self.lastVelocity = lastVelocity
            self.velocityDropPercent = velocityDropPercent
        }
    }

    public var exerciseName: String
    public var startedAt: Date

    public init(exerciseName: String, startedAt: Date = Date()) {
        self.exerciseName = exerciseName
        self.startedAt = startedAt
    }
}

// MARK: - AppIntents / Deep-Link Navigation Bus
@MainActor
public final class ApexNavigationRouter: ObservableObject {
    public static let shared = ApexNavigationRouter()

    @Published public var selectedTab: Int = 0
    @Published public var requestedExerciseRaw: String? = nil
    @Published public var requestedTrainSegment: Int? = nil
    @Published public var shouldAutoStartDeadHang: Bool = false

    private init() {}

    public func openURL(_ url: URL) {
        guard url.scheme == "apex" else { return }
        switch url.host {
        case "summary": selectedTab = 0
        case "face": selectedTab = 1
        case "train":
            selectedTab = 2
            if let ex = url.pathComponents.dropFirst().first, !ex.isEmpty {
                requestedExerciseRaw = ex
            }
        case "nutrition", "fuel":
            selectedTab = 3
        case "longevity", "biology":
            selectedTab = 4
            if url.pathComponents.contains("deadhang") {
                shouldAutoStartDeadHang = true
            }
        default: break
        }
    }
}
