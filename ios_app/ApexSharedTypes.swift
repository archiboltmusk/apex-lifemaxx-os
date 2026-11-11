import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(ActivityKit) && !os(watchOS)
import ActivityKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

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

    // Interactive Widget -> Main App Action Queue (App Group backed)
    public static var sharedDefaults: UserDefaults { defaults }

    public static func queueHydrationIncrement(ml: Double = 250) {
        let dayKey = todayKey()
        let currentDay = defaults.string(forKey: "apex_widget_water_day")
        let prevMl = (currentDay == dayKey) ? defaults.double(forKey: "apex_widget_water_pending_ml") : 0
        defaults.set(dayKey, forKey: "apex_widget_water_day")
        defaults.set(prevMl + ml, forKey: "apex_widget_water_pending_ml")
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    public static func consumePendingHydrationMl() -> Double {
        let dayKey = todayKey()
        guard defaults.string(forKey: "apex_widget_water_day") == dayKey else { return 0 }
        let pending = defaults.double(forKey: "apex_widget_water_pending_ml")
        if pending > 0 {
            defaults.set(0, forKey: "apex_widget_water_pending_ml")
        }
        return pending
    }

    public static func queuePendingJournalTag(_ tagId: String) {
        let dayKey = todayKey()
        let keyName = "apex_widget_pending_tags_\(dayKey)"
        var list = defaults.stringArray(forKey: keyName) ?? []
        if !list.contains(tagId) {
            list.append(tagId)
            defaults.set(list, forKey: keyName)
        }
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    public static func consumePendingJournalTags() -> [String] {
        let keyName = "apex_widget_pending_tags_\(todayKey())"
        let tags = defaults.stringArray(forKey: keyName) ?? []
        if !tags.isEmpty {
            defaults.removeObject(forKey: keyName)
        }
        return tags
    }

    private static func todayKey() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

// MARK: - Unit Preferences (Metric kg / mg·dL vs Imperial lbs / mmol·L)
public enum ApexUnitSystem: String, Codable, CaseIterable, Identifiable {
    case metric
    case imperial
    public var id: String { rawValue }
    public var displayLabel: String {
        switch self {
        case .metric: return "Metric (kg · mg/dL)"
        case .imperial: return "Imperial (lbs · mmol/L)"
        }
    }
}

public enum ApexUnitPreferences {
    private static let unitKey = "apex_unit_system_v1"

    public static var current: ApexUnitSystem {
        get {
            let raw = ApexSnapshotStore.sharedDefaults.string(forKey: unitKey)
                ?? UserDefaults.standard.string(forKey: unitKey)
                ?? "metric"
            return ApexUnitSystem(rawValue: raw) ?? .metric
        }
        set {
            ApexSnapshotStore.sharedDefaults.set(newValue.rawValue, forKey: unitKey)
            UserDefaults.standard.set(newValue.rawValue, forKey: unitKey)
        }
    }

    public static func formatWeight(kg: Double) -> String {
        switch current {
        case .metric:
            return String(format: "%.1f kg", kg)
        case .imperial:
            return String(format: "%.1f lbs", kg * 2.20462)
        }
    }

    public static func formatGlucose(mgDl: Double) -> String {
        switch current {
        case .metric:
            return "\(Int(mgDl.rounded())) mg/dL"
        case .imperial:
            return String(format: "%.1f mmol/L", mgDl / 18.0182)
        }
    }
}

// MARK: - Shared Pure Biometric & Bevel Formula Engine (Tested via Automated Unit Suite)
public enum ApexBiometricMath {
    public static func dailyStrain(moveKcal: Double, exerciseMinutes: Double, strengthSetsBonus: Double = 0) -> Double? {
        guard moveKcal > 0 || exerciseMinutes > 0 || strengthSetsBonus > 0 else { return nil }
        let cardLoad = (moveKcal / 110.0) + (exerciseMinutes / 18.0) + strengthSetsBonus
        let scaled = 21.0 * (1.0 - exp(-cardLoad / 10.5))
        return min(21.0, max(0.0, (scaled * 10.0).rounded() / 10.0))
    }

    public static func targetStrainRange(readiness: Int?) -> ClosedRange<Double>? {
        guard let r = readiness else { return nil }
        let low = max(4.0, (6.0 + (Double(r) / 100.0) * 8.0).rounded())
        let high = min(20.0, low + 4.0)
        return low...high
    }

    public static func energyBank(readiness: Int?, strain: Double?, napHours: Double = 0) -> Int? {
        guard let r = readiness else { return nil }
        let drain = (strain ?? 0) * 2.3
        let recharge = napHours * 18.0
        return Int(min(100.0, max(5.0, (Double(r) - drain + recharge).rounded())))
    }

    public static func brzycki1RM(weightKg: Double, reps: Int) -> Double {
        guard weightKg > 0, reps >= 1 else { return 0 }
        let cappedReps = min(reps, 36)
        return (weightKg * (36.0 / Double(37 - cappedReps)) * 10.0).rounded() / 10.0
    }

    public static func nutritionQualityScore(
        calories: Double,
        calorieTarget: Double,
        proteinG: Double,
        proteinTargetG: Double,
        fiberG: Double,
        fiberTargetG: Double,
        sugarG: Double,
        wholeFoodRatio: Double,
        mealCount: Int
    ) -> Int? {
        guard mealCount > 0 else { return nil }
        let calRatio = calorieTarget > 0 ? min(1.2, calories / calorieTarget) : 1.0
        let proteinRatio = min(1.0, proteinG / max(60.0, proteinTargetG))
        let fiberRatio = min(1.0, fiberG / max(15.0, fiberTargetG))
        let sugarPenalty = max(0.0, (sugarG - 38.0) * 0.45)
        let raw = 28.0
            + proteinRatio * 34.0
            + fiberRatio * 18.0
            + min(1.0, max(0.0, wholeFoodRatio)) * 15.0
            + (calRatio >= 0.7 && calRatio <= 1.15 ? 5.0 : 0.0)
            - sugarPenalty
        return Int(max(12.0, min(100.0, raw.rounded())))
    }
}

#if canImport(ActivityKit) && os(iOS)
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
#endif

#if canImport(SwiftUI) && !os(watchOS)
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
#endif
