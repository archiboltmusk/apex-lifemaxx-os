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

// MARK: - Elite Biometric Intelligence Models (Whoop, Bevel, Oura, MacroFactor & Blueprint Parity)
public enum TrainingZone: String, Codable {
    case underTraining = "Under-training"
    case optimal = "Optimal Sweet Spot"
    case overreaching = "Overreaching"
    case injuryRisk = "High Injury Risk"
}

public struct ACWRResult: Codable, Equatable {
    public let acuteLoad7d: Double
    public let chronicLoad28d: Double
    public let ratio: Double
    public let zone: TrainingZone
    public let recommendation: String

    public init(acuteLoad7d: Double, chronicLoad28d: Double, ratio: Double, zone: TrainingZone, recommendation: String) {
        self.acuteLoad7d = acuteLoad7d
        self.chronicLoad28d = chronicLoad28d
        self.ratio = ratio
        self.zone = zone
        self.recommendation = recommendation
    }
}

public struct CardiovascularAgeResult: Codable, Equatable {
    public let cardiovascularAge: Double
    public let chronologicalAge: Double
    public let ageDelta: Double
    public let elasticityStatus: String
    public let vo2MaxPercentile: Int
    public let recommendation: String

    public init(cardiovascularAge: Double, chronologicalAge: Double, ageDelta: Double, elasticityStatus: String, vo2MaxPercentile: Int, recommendation: String) {
        self.cardiovascularAge = cardiovascularAge
        self.chronologicalAge = chronologicalAge
        self.ageDelta = ageDelta
        self.elasticityStatus = elasticityStatus
        self.vo2MaxPercentile = vo2MaxPercentile
        self.recommendation = recommendation
    }
}

public enum Chronotype: String, Codable {
    case earlyLark = "Early Lark"
    case morningType = "Morning Active"
    case intermediate = "Balanced Type"
    case eveningType = "Evening Active"
    case nightOwl = "Night Owl"
}

public struct CircadianProfile: Codable, Equatable {
    public let chronotype: Chronotype
    public let sleepMidpointHours: Double
    public let sleepMidpointFormatted: String
    public let regularityScore: Int
    public let optimalBedtimeFormatted: String
    public let optimalWakeFormatted: String
    public let melatoninWindowStartFormatted: String
    public let cortisolAwakeningFormatted: String

    public init(chronotype: Chronotype, sleepMidpointHours: Double, sleepMidpointFormatted: String, regularityScore: Int, optimalBedtimeFormatted: String, optimalWakeFormatted: String, melatoninWindowStartFormatted: String, cortisolAwakeningFormatted: String) {
        self.chronotype = chronotype
        self.sleepMidpointHours = sleepMidpointHours
        self.sleepMidpointFormatted = sleepMidpointFormatted
        self.regularityScore = regularityScore
        self.optimalBedtimeFormatted = optimalBedtimeFormatted
        self.optimalWakeFormatted = optimalWakeFormatted
        self.melatoninWindowStartFormatted = melatoninWindowStartFormatted
        self.cortisolAwakeningFormatted = cortisolAwakeningFormatted
    }
}

public struct AdaptiveTDEEResult: Codable, Equatable {
    public let calculatedTDEE: Double
    public let weightTrendKgPerWeek: Double
    public let energyBalanceKcal: Double
    public let fatLossTargetKcal: Double
    public let maintenanceTargetKcal: Double
    public let leanBulkTargetKcal: Double
    public let recommendedProteinG: Double
    public let metabolicAdaptationDelta: Double

    public init(calculatedTDEE: Double, weightTrendKgPerWeek: Double, energyBalanceKcal: Double, fatLossTargetKcal: Double, maintenanceTargetKcal: Double, leanBulkTargetKcal: Double, recommendedProteinG: Double, metabolicAdaptationDelta: Double) {
        self.calculatedTDEE = calculatedTDEE
        self.weightTrendKgPerWeek = weightTrendKgPerWeek
        self.energyBalanceKcal = energyBalanceKcal
        self.fatLossTargetKcal = fatLossTargetKcal
        self.maintenanceTargetKcal = maintenanceTargetKcal
        self.leanBulkTargetKcal = leanBulkTargetKcal
        self.recommendedProteinG = recommendedProteinG
        self.metabolicAdaptationDelta = metabolicAdaptationDelta
    }
}

public enum OrganPillar: String, Codable, CaseIterable {
    case cardiovascular
    case metabolic
    case autonomic
    case musculoskeletal
    case immune
    case epigenetic
}

public struct OrganPillarScore: Codable, Identifiable, Equatable {
    public var id: String { pillar.rawValue }
    public let pillar: OrganPillar
    public let name: String
    public let icon: String
    public let age: Double
    public let status: String
    public let keyMetric: String
    public let recommendation: String

    public init(pillar: OrganPillar, name: String, icon: String, age: Double, status: String, keyMetric: String, recommendation: String) {
        self.pillar = pillar
        self.name = name
        self.icon = icon
        self.age = age
        self.status = status
        self.keyMetric = keyMetric
        self.recommendation = recommendation
    }
}

public struct OrganScorecard: Codable, Equatable {
    public let pillars: [OrganPillarScore]
    public let compositeAge: Double

    public init(pillars: [OrganPillarScore], compositeAge: Double) {
        self.pillars = pillars
        self.compositeAge = compositeAge
    }
}

public struct WeeklyPerformanceReport: Codable, Equatable {
    public let sleepPerformancePct: Int
    public let sleepConsistencyPct: Int
    public let optimalStrainDays: Int
    public let acwrAverage: Double
    public let strainRecoveryAlignment: String
    public let topPositiveHabit: String?
    public let topNegativeHabit: String?
    public let avgHrv: Double?
    public let avgRhr: Double?
    public let totalMoveKcal: Double

    public init(sleepPerformancePct: Int, sleepConsistencyPct: Int, optimalStrainDays: Int, acwrAverage: Double, strainRecoveryAlignment: String, topPositiveHabit: String?, topNegativeHabit: String?, avgHrv: Double?, avgRhr: Double?, totalMoveKcal: Double) {
        self.sleepPerformancePct = sleepPerformancePct
        self.sleepConsistencyPct = sleepConsistencyPct
        self.optimalStrainDays = optimalStrainDays
        self.acwrAverage = acwrAverage
        self.strainRecoveryAlignment = strainRecoveryAlignment
        self.topPositiveHabit = topPositiveHabit
        self.topNegativeHabit = topNegativeHabit
        self.avgHrv = avgHrv
        self.avgRhr = avgRhr
        self.totalMoveKcal = totalMoveKcal
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
    public var waterMlToday: Double
    public var caffeineMgToday: Double
    public var sunlightLoggedToday: Bool
    public var paceOfAging: Double?
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
        waterMlToday: Double = 0,
        caffeineMgToday: Double = 0,
        sunlightLoggedToday: Bool = false,
        paceOfAging: Double? = nil,
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
        self.waterMlToday = waterMlToday
        self.caffeineMgToday = caffeineMgToday
        self.sunlightLoggedToday = sunlightLoggedToday
        self.paceOfAging = paceOfAging
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.moveCalories = try c.decodeIfPresent(Double.self, forKey: .moveCalories) ?? 0
        self.moveTarget = try c.decodeIfPresent(Double.self, forKey: .moveTarget) ?? 750
        self.exerciseMinutes = try c.decodeIfPresent(Double.self, forKey: .exerciseMinutes) ?? 0
        self.exerciseTarget = try c.decodeIfPresent(Double.self, forKey: .exerciseTarget) ?? 30
        self.standHours = try c.decodeIfPresent(Double.self, forKey: .standHours) ?? 0
        self.standTarget = try c.decodeIfPresent(Double.self, forKey: .standTarget) ?? 12
        self.readinessScore = try c.decodeIfPresent(Int.self, forKey: .readinessScore)
        self.energyBank = try c.decodeIfPresent(Int.self, forKey: .energyBank)
        self.strainScore = try c.decodeIfPresent(Double.self, forKey: .strainScore)
        self.hrv = try c.decodeIfPresent(Double.self, forKey: .hrv)
        self.hrvDeltaPercent = try c.decodeIfPresent(Int.self, forKey: .hrvDeltaPercent)
        self.restingHR = try c.decodeIfPresent(Double.self, forKey: .restingHR)
        self.sleepHours = try c.decodeIfPresent(Double.self, forKey: .sleepHours)
        self.biologicalAge = try c.decodeIfPresent(Double.self, forKey: .biologicalAge)
        self.clinicalPhenoAge = try c.decodeIfPresent(Double.self, forKey: .clinicalPhenoAge)
        self.deadHangBestSec = try c.decodeIfPresent(Int.self, forKey: .deadHangBestSec) ?? 0
        self.dailySteps = try c.decodeIfPresent(Int.self, forKey: .dailySteps) ?? 0
        self.waterMlToday = try c.decodeIfPresent(Double.self, forKey: .waterMlToday) ?? 0
        self.caffeineMgToday = try c.decodeIfPresent(Double.self, forKey: .caffeineMgToday) ?? 0
        self.sunlightLoggedToday = try c.decodeIfPresent(Bool.self, forKey: .sunlightLoggedToday) ?? false
        self.paceOfAging = try c.decodeIfPresent(Double.self, forKey: .paceOfAging)
        self.updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
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
    public static let unitKey = "apex_unit_system_v1"

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

    public static var isImperial: Bool {
        current == .imperial
    }

    public static var weightUnitLabel: String {
        current == .metric ? "kg" : "lbs"
    }

    public static var glucoseUnitLabel: String {
        current == .metric ? "mg/dL" : "mmol/L"
    }

    public static func weightValue(kg: Double) -> Double {
        current == .metric ? kg : kg * 2.20462
    }

    public static func kgFromWeightInput(_ value: Double) -> Double {
        current == .metric ? value : value / 2.20462
    }

    public static func glucoseValue(mgDl: Double) -> Double {
        current == .metric ? mgDl : mgDl / 18.0182
    }

    public static func mgDlFromGlucoseInput(_ value: Double) -> Double {
        current == .metric ? value : value * 18.0182
    }

    public static func formatVolume(ml: Double) -> String {
        switch current {
        case .metric:
            if ml >= 1000 { return String(format: "%.2f L", ml / 1000.0) }
            return "\(Int(ml.rounded())) mL"
        case .imperial:
            return String(format: "%.1f fl oz", ml * 0.033814)
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

    /// DunedinPACE-inspired Aging Velocity (`1.00` = normal calendar pace; `< 1.00` slower biological aging).
    public static func paceOfAging(
        chronologicalAge: Double,
        biologicalAge: Double?,
        clinicalPhenoAge: Double?,
        hrv: Double?,
        hrvBaseline: Double?,
        rhr: Double?,
        rhrBaseline: Double?,
        vo2Max: Double?,
        sleepEfficiencyPercent: Int?
    ) -> Double? {
        guard biologicalAge != nil || clinicalPhenoAge != nil || hrv != nil || rhr != nil || vo2Max != nil else {
            return nil
        }
        var velocity = 1.00
        if let pheno = clinicalPhenoAge {
            velocity += max(-0.22, min(0.25, (pheno - chronologicalAge) * 0.024))
        } else if let bio = biologicalAge {
            velocity += max(-0.18, min(0.20, (bio - chronologicalAge) * 0.020))
        }
        if let hrv = hrv, let base = hrvBaseline, base > 1 {
            velocity -= max(-0.08, min(0.08, ((hrv - base) / base) * 0.25))
        }
        if let rhr = rhr, let base = rhrBaseline {
            velocity += max(-0.07, min(0.09, (rhr - base) * 0.012))
        }
        if let vo2 = vo2Max {
            velocity -= max(-0.09, min(0.09, (vo2 - 44.0) * 0.005))
        }
        if let eff = sleepEfficiencyPercent {
            velocity -= max(-0.05, min(0.06, Double(eff - 84) * 0.003))
        }
        let clamped = max(0.58, min(1.48, velocity))
        return (clamped * 100.0).rounded() / 100.0
    }

    /// First-order caffeine pharmacokinetics using standard 5.7h elimination half-life.
    public static func caffeineRemainingMg(intakeMg: Double, hoursElapsed: Double, halfLifeHours: Double = 5.7) -> Double {
        guard intakeMg > 0, hoursElapsed >= 0, halfLifeHours > 0 else { return 0 }
        let rem = intakeMg * pow(0.5, hoursElapsed / halfLifeHours)
        return (rem * 10.0).rounded() / 10.0
    }

    private static let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    /// Shifts `"YYYY-MM-DD"` habit day keys to next-day `"YYYY-MM-DD"` outcome keys (Lag-1 D -> D+1 causality).
    public static func lag1ShiftedKeys(_ dayKeys: Set<String>) -> Set<String> {
        let cal = Calendar(identifier: .gregorian)
        return Set(dayKeys.compactMap { key in
            guard let dt = dayFormatter.date(from: key),
                  let next = cal.date(byAdding: .day, value: 1, to: dt) else { return nil }
            return dayFormatter.string(from: next)
        })
    }

    public static func meanPercentDelta(onValues: [Double], offValues: [Double]) -> Double? {
        guard !onValues.isEmpty, !offValues.isEmpty else { return nil }
        let mOn = onValues.reduce(0, +) / Double(onValues.count)
        let mOff = offValues.reduce(0, +) / Double(offValues.count)
        guard mOff > 0 else { return nil }
        return ((mOn - mOff) / mOff) * 100.0
    }

    public static func meanAbsoluteDelta(onValues: [Double], offValues: [Double], scale: Double = 1.0) -> Double? {
        guard !onValues.isEmpty, !offValues.isEmpty else { return nil }
        let mOn = onValues.reduce(0, +) / Double(onValues.count)
        let mOff = offValues.reduce(0, +) / Double(offValues.count)
        return (mOn - mOff) * scale
    }

    // MARK: - Acute:Chronic Workload Ratio (ACWR / Gabbett 2016 Model)
    public static func acwr(acute7dLoad: Double, chronic28dLoad: Double) -> ACWRResult {
        let safeChronic = max(0.5, chronic28dLoad)
        let ratio = (acute7dLoad / safeChronic * 100.0).rounded() / 100.0
        let zone: TrainingZone
        let recommendation: String

        if ratio < 0.80 {
            zone = .underTraining
            recommendation = "Workload below chronic adaptation. Low acute stimulus; ideal for active recovery or deload."
        } else if ratio <= 1.30 {
            zone = .optimal
            recommendation = "Optimal training sweet spot. Builds cardiovascular & muscular fitness with minimal injury hazard."
        } else if ratio <= 1.50 {
            zone = .overreaching
            recommendation = "Functional overreaching. Workload spike detected; prioritize 8+ hours sleep and recovery protocols."
        } else {
            zone = .injuryRisk
            recommendation = "High injury hazard (ACWR > 1.50). Acute strain spike exceeds chronic tolerance. Rest or down-regulate today."
        }

        return ACWRResult(
            acuteLoad7d: (acute7dLoad * 10.0).rounded() / 10.0,
            chronicLoad28d: (chronic28dLoad * 10.0).rounded() / 10.0,
            ratio: ratio,
            zone: zone,
            recommendation: recommendation
        )
    }

    // MARK: - Cardiovascular Age & Arterial Compliance Model
    public static func cardiovascularAge(
        chronologicalAge: Double,
        vo2Max: Double?,
        rhr: Double?,
        hrv: Double?,
        sex: String? = nil
    ) -> CardiovascularAgeResult {
        var delta = 0.0
        let baseVO2 = (sex?.lowercased() == "female") ? 36.0 : 42.0
        var vo2Percentile = 50
        if let vo2 = vo2Max {
            let vo2Delta = vo2 - baseVO2
            delta -= vo2Delta * 0.55
            if vo2 >= baseVO2 + 12 { vo2Percentile = 95 }
            else if vo2 >= baseVO2 + 6 { vo2Percentile = 80 }
            else if vo2 >= baseVO2 { vo2Percentile = 60 }
            else if vo2 >= baseVO2 - 6 { vo2Percentile = 35 }
            else { vo2Percentile = 15 }
        }

        if let r = rhr {
            delta += (r - 60.0) * 0.28
        }

        if let h = hrv {
            delta -= (h - 50.0) * 0.12
        }

        let cardioAge = max(18.0, min(95.0, ((chronologicalAge + delta) * 10.0).rounded() / 10.0))
        let ageDelta = ((cardioAge - chronologicalAge) * 10.0).rounded() / 10.0

        let status: String
        let rec: String
        if ageDelta <= -4.0 {
            status = "Youthful / Athletic Elasticity"
            rec = "Arterial compliance and aerobic capacity match elite longevity benchmarks. Maintain current Zone 2 volume."
        } else if ageDelta <= 1.0 {
            status = "Healthy Age-Matched Compliance"
            rec = "Cardiovascular biomarkers align with chronological baseline. Add 1 weekly VO2 max 4x4 interval session."
        } else {
            status = "Elevated Vascular Stiffness"
            rec = "Vascular age exceeds chronological age. Prioritize 150 min/wk Zone 2 cardio, nitric oxide foods, and RHR lowering."
        }

        return CardiovascularAgeResult(
            cardiovascularAge: cardioAge,
            chronologicalAge: chronologicalAge,
            ageDelta: ageDelta,
            elasticityStatus: status,
            vo2MaxPercentile: vo2Percentile,
            recommendation: rec
        )
    }

    // MARK: - Circadian Chronotype & Optimal Sleep Alignment (Roenneberg / MCTQ Model)
    public static func circadianProfile(
        sleepMidpointHours: Double,
        regularityScore: Int = 85
    ) -> CircadianProfile {
        let chronotype: Chronotype
        let optimalBedHour: Double
        let optimalWakeHour: Double

        if sleepMidpointHours < 2.75 {
            chronotype = .earlyLark
            optimalBedHour = 21.75
            optimalWakeHour = 5.75
        } else if sleepMidpointHours < 3.50 {
            chronotype = .morningType
            optimalBedHour = 22.50
            optimalWakeHour = 6.50
        } else if sleepMidpointHours < 4.50 {
            chronotype = .intermediate
            optimalBedHour = 23.25
            optimalWakeHour = 7.25
        } else if sleepMidpointHours < 5.25 {
            chronotype = .eveningType
            optimalBedHour = 24.00
            optimalWakeHour = 8.00
        } else {
            chronotype = .nightOwl
            optimalBedHour = 24.75
            optimalWakeHour = 8.75
        }

        func formatClock(decimalHours: Double) -> String {
            var h = Int(decimalHours.truncatingRemainder(dividingBy: 24.0))
            if h < 0 { h += 24 }
            let m = Int(((decimalHours - floor(decimalHours)) * 60.0).rounded())
            let period = (h >= 12 && h < 24) ? "PM" : "AM"
            let h12 = (h == 0) ? 12 : (h > 12 ? h - 12 : h)
            return String(format: "%d:%02d %@", h12, m, period)
        }

        let bedtimeStr = formatClock(decimalHours: optimalBedHour)
        let wakeStr = formatClock(decimalHours: optimalWakeHour)
        let melatoninStr = formatClock(decimalHours: optimalBedHour - 2.0)
        let cortisolStr = formatClock(decimalHours: optimalWakeHour + 0.5)

        return CircadianProfile(
            chronotype: chronotype,
            sleepMidpointHours: (sleepMidpointHours * 100.0).rounded() / 100.0,
            sleepMidpointFormatted: formatClock(decimalHours: sleepMidpointHours),
            regularityScore: min(100, max(10, regularityScore)),
            optimalBedtimeFormatted: bedtimeStr,
            optimalWakeFormatted: wakeStr,
            melatoninWindowStartFormatted: melatoninStr,
            cortisolAwakeningFormatted: cortisolStr
        )
    }

    // MARK: - Adaptive Dynamic TDEE & Macro Coach (MacroFactor / Hall et al. Model)
    public static func adaptiveTDEE(
        weightHistory: [DailyMetricPoint],
        calorieHistory: [DailyMetricPoint],
        fallbackBasalKcal: Double,
        fallbackActiveKcal: Double,
        bodyWeightKg: Double = 75.0
    ) -> AdaptiveTDEEResult {
        let baselineExpenditure = max(1400.0, fallbackBasalKcal + fallbackActiveKcal)
        var calculatedExpenditure = baselineExpenditure
        var weightDeltaKgPerWeek = 0.0
        var energyBalance = 0.0

        if weightHistory.count >= 3 && calorieHistory.count >= 3 {
            let recentCalories = calorieHistory.suffix(14)
            let avgCalories = recentCalories.reduce(0.0) { $0 + $1.value } / Double(recentCalories.count)
            let firstWeight = weightHistory.prefix(3).reduce(0.0) { $0 + $1.value } / Double(min(3, weightHistory.count))
            let lastWeight = weightHistory.suffix(3).reduce(0.0) { $0 + $1.value } / Double(min(3, weightHistory.count))
            let daysBetween = max(3.0, Double(min(14, weightHistory.count)))
            let dailyWeightDelta = (lastWeight - firstWeight) / daysBetween
            weightDeltaKgPerWeek = dailyWeightDelta * 7.0
            energyBalance = dailyWeightDelta * 7700.0
            let empiricalTDEE = avgCalories - energyBalance
            calculatedExpenditure = empiricalTDEE * 0.75 + baselineExpenditure * 0.25
        }

        let tdee = max(1300.0, min(4800.0, (calculatedExpenditure / 10.0).rounded() * 10.0))
        let fatLoss = ((tdee * 0.80) / 10.0).rounded() * 10.0
        let maintenance = tdee
        let leanBulk = ((tdee * 1.10) / 10.0).rounded() * 10.0
        let targetProtein = (bodyWeightKg * 2.0).rounded()
        let adaptation = (tdee - (fallbackBasalKcal + fallbackActiveKcal)).rounded()

        return AdaptiveTDEEResult(
            calculatedTDEE: tdee,
            weightTrendKgPerWeek: (weightDeltaKgPerWeek * 100.0).rounded() / 100.0,
            energyBalanceKcal: (energyBalance * 10.0).rounded() / 10.0,
            fatLossTargetKcal: fatLoss,
            maintenanceTargetKcal: maintenance,
            leanBulkTargetKcal: leanBulk,
            recommendedProteinG: targetProtein,
            metabolicAdaptationDelta: adaptation
        )
    }

    // MARK: - Organ-by-Organ Longevity Scorecard (Bryan Johnson / Levine 6-Pillar Model)
    public static func organScorecard(
        chronologicalAge: Double,
        vo2Max: Double?,
        rhr: Double?,
        hrv: Double?,
        fastingGlucoseMgDL: Double?,
        hba1cPct: Double?,
        activeKcal: Double,
        bodyFatPct: Double?,
        deadHangSec: Int,
        spatialPostureScore: Int?,
        crpMgL: Double?,
        albuminGDL: Double?,
        paceOfAging: Double?,
        clinicalPhenoAge: Double?
    ) -> OrganScorecard {
        var cvDelta = 0.0
        if let vo2 = vo2Max { cvDelta -= (vo2 - 42.0) * 0.45 }
        if let r = rhr { cvDelta += (r - 60.0) * 0.25 }
        let cvAge = max(18.0, min(95.0, ((chronologicalAge + cvDelta) * 10.0).rounded() / 10.0))
        let cvStatus = cvAge <= chronologicalAge - 2 ? "Optimal" : (cvAge <= chronologicalAge + 1 ? "Good" : "Needs Attention")
        let cvPillar = OrganPillarScore(
            pillar: .cardiovascular,
            name: "Cardiovascular System",
            icon: "heart.fill",
            age: cvAge,
            status: cvStatus,
            keyMetric: vo2Max.map { String(format: "VO2 Max %.1f ml/kg", $0) } ?? (rhr.map { "RHR \(Int($0)) bpm" } ?? "Aerobic Base"),
            recommendation: cvStatus == "Optimal" ? "Superior aerobic capacity. Maintain Zone 2 volume." : "Increase weekly Zone 2 cardio and add 4x4 intervals."
        )

        var metaDelta = 0.0
        if let glu = fastingGlucoseMgDL {
            if glu < 85 { metaDelta -= 1.8 }
            else if glu > 100 { metaDelta += 2.8 }
        }
        if let a1c = hba1cPct {
            if a1c < 5.3 { metaDelta -= 1.5 }
            else if a1c > 5.7 { metaDelta += 3.0 }
        }
        if let bf = bodyFatPct {
            if bf <= 16 { metaDelta -= 1.2 }
            else if bf > 24 { metaDelta += 2.4 }
        }
        if activeKcal >= 600 { metaDelta -= 1.0 }
        let metaAge = max(18.0, min(95.0, ((chronologicalAge + metaDelta) * 10.0).rounded() / 10.0))
        let metaStatus = metaAge <= chronologicalAge - 1 ? "Optimal" : (metaAge <= chronologicalAge + 2 ? "Good" : "Needs Attention")
        let metaPillar = OrganPillarScore(
            pillar: .metabolic,
            name: "Metabolic & Insulin Health",
            icon: "flame.fill",
            age: metaAge,
            status: metaStatus,
            keyMetric: hba1cPct.map { String(format: "HbA1c %.1f%%", $0) } ?? (fastingGlucoseMgDL.map { "Fasting Glu \(Int($0)) mg/dL" } ?? "\(Int(activeKcal)) kcal burn"),
            recommendation: metaStatus == "Optimal" ? "High insulin sensitivity and whole-food fuel partition." : "Time carbs around resistance training; add post-meal 10m walks."
        )

        var autoDelta = 0.0
        if let h = hrv {
            if h >= 65 { autoDelta -= 2.5 }
            else if h < 38 { autoDelta += 3.0 }
        }
        let autoAge = max(18.0, min(95.0, ((chronologicalAge + autoDelta) * 10.0).rounded() / 10.0))
        let autoStatus = autoAge <= chronologicalAge - 1 ? "Optimal" : (autoAge <= chronologicalAge + 1 ? "Good" : "Needs Attention")
        let autoPillar = OrganPillarScore(
            pillar: .autonomic,
            name: "Autonomic Nervous System",
            icon: "brain.head.profile",
            age: autoAge,
            status: autoStatus,
            keyMetric: hrv.map { "\(Int($0)) ms HRV" } ?? "Stress/Sleep Base",
            recommendation: autoStatus == "Optimal" ? "High parasympathetic vagal tone and stress resilience." : "Practice coherent resonance breathwork (5.5s inhale / 5.5s exhale)."
        )

        var muskDelta = 0.0
        if deadHangSec >= 90 { muskDelta -= 2.2 }
        else if deadHangSec >= 60 { muskDelta -= 1.0 }
        else if deadHangSec > 0 && deadHangSec < 35 { muskDelta += 1.8 }
        if let post = spatialPostureScore {
            if post >= 85 { muskDelta -= 1.0 }
            else if post < 65 { muskDelta += 1.5 }
        }
        let muskAge = max(18.0, min(95.0, ((chronologicalAge + muskDelta) * 10.0).rounded() / 10.0))
        let muskStatus = muskAge <= chronologicalAge - 1 ? "Optimal" : (muskAge <= chronologicalAge + 1 ? "Good" : "Needs Attention")
        let muskPillar = OrganPillarScore(
            pillar: .musculoskeletal,
            name: "Musculoskeletal & Grip",
            icon: "figure.strengthtraining.traditional",
            age: muskAge,
            status: muskStatus,
            keyMetric: "\(deadHangSec)s Dead Hang" + (spatialPostureScore.map { " · \($0)% posture" } ?? ""),
            recommendation: muskStatus == "Optimal" ? "Grip strength and spinal alignment in longevity top tier." : "Progressive overload on dead hangs (target 90s) & spatial posture."
        )

        var immDelta = 0.0
        if let crp = crpMgL {
            if crp < 0.6 { immDelta -= 2.0 }
            else if crp > 1.5 { immDelta += 2.5 }
        }
        if let alb = albuminGDL {
            if alb >= 4.5 { immDelta -= 1.2 }
            else if alb < 4.0 { immDelta += 1.8 }
        }
        let immAge = max(18.0, min(95.0, ((chronologicalAge + immDelta) * 10.0).rounded() / 10.0))
        let immStatus = immAge <= chronologicalAge - 1 ? "Optimal" : (immAge <= chronologicalAge + 1 ? "Good" : "Needs Attention")
        let immPillar = OrganPillarScore(
            pillar: .immune,
            name: "Immune & Systemic Inflammation",
            icon: "shield.lefthalf.filled",
            age: immAge,
            status: immStatus,
            keyMetric: crpMgL.map { String(format: "hs-CRP %.2f mg/L", $0) } ?? (albuminGDL.map { String(format: "Albumin %.1f g/dL", $0) } ?? "Lab Panel"),
            recommendation: immStatus == "Optimal" ? "Minimal systemic baseline inflammation." : "Increase omega-3 index (wild salmon/EPA) and polyphenol density."
        )

        var epiDelta = 0.0
        if let pace = paceOfAging {
            epiDelta += (pace - 1.0) * 8.0
        } else if let pheno = clinicalPhenoAge {
            epiDelta += (pheno - chronologicalAge) * 0.6
        }
        let epiAge = max(18.0, min(95.0, ((chronologicalAge + epiDelta) * 10.0).rounded() / 10.0))
        let epiStatus = epiAge <= chronologicalAge - 1 ? "Optimal" : (epiAge <= chronologicalAge + 1 ? "Good" : "Needs Attention")
        let epiPillar = OrganPillarScore(
            pillar: .epigenetic,
            name: "Epigenetic & Aging Velocity",
            icon: "hourglass",
            age: epiAge,
            status: epiStatus,
            keyMetric: paceOfAging.map { String(format: "%.2f yr/yr pace", $0) } ?? (clinicalPhenoAge.map { String(format: "PhenoAge %.1f", $0) } ?? "Epigenetic Baseline"),
            recommendation: epiStatus == "Optimal" ? "Biological aging rate significantly decelerated." : "Prioritize sleep consistency, cold/heat hormesis, and caloric moderation."
        )

        let pillars = [cvPillar, metaPillar, autoPillar, muskPillar, immPillar, epiPillar]
        let composite = (pillars.reduce(0.0) { $0 + $1.age } / Double(pillars.count) * 10.0).rounded() / 10.0

        return OrganScorecard(pillars: pillars, compositeAge: composite)
    }
}

// MARK: - On-Device Whole-Food Describe-to-Log Parser
public enum DescribeMealParser {
    private struct FoodRef {
        let aliases: [String]
        let label: String
        let per100gCal: Double
        let per100gPro: Double
        let per100gCarb: Double
        let per100gFat: Double
        let per100gFiber: Double
        let per100gSugar: Double
        let defaultServingGrams: Double
    }

    private static let table: [FoodRef] = [
        FoodRef(aliases: ["egg white", "egg whites"], label: "Egg Whites", per100gCal: 52, per100gPro: 11, per100gCarb: 0.7, per100gFat: 0.2, per100gFiber: 0, per100gSugar: 0.7, defaultServingGrams: 100),
        FoodRef(aliases: ["whole eggs", "whole egg", "eggs", "egg"], label: "Whole Eggs", per100gCal: 143, per100gPro: 12.6, per100gCarb: 0.7, per100gFat: 9.5, per100gFiber: 0, per100gSugar: 0.4, defaultServingGrams: 50),
        FoodRef(aliases: ["chicken breast", "chicken"], label: "Chicken Breast", per100gCal: 165, per100gPro: 31, per100gCarb: 0, per100gFat: 3.6, per100gFiber: 0, per100gSugar: 0, defaultServingGrams: 170),
        FoodRef(aliases: ["salmon"], label: "Wild Salmon", per100gCal: 208, per100gPro: 20.4, per100gCarb: 0, per100gFat: 13.4, per100gFiber: 0, per100gSugar: 0, defaultServingGrams: 170),
        FoodRef(aliases: ["ribeye", "steak", "beef"], label: "Lean Steak / Beef", per100gCal: 250, per100gPro: 26, per100gCarb: 0, per100gFat: 15, per100gFiber: 0, per100gSugar: 0, defaultServingGrams: 180),
        FoodRef(aliases: ["white rice", "rice"], label: "Cooked White Rice", per100gCal: 130, per100gPro: 2.7, per100gCarb: 28.2, per100gFat: 0.3, per100gFiber: 0.4, per100gSugar: 0.1, defaultServingGrams: 160),
        FoodRef(aliases: ["oatmeal", "oats"], label: "Rolled Oats (Dry)", per100gCal: 389, per100gPro: 16.9, per100gCarb: 66.3, per100gFat: 6.9, per100gFiber: 10.6, per100gSugar: 0.9, defaultServingGrams: 60),
        FoodRef(aliases: ["greek yogurt", "yogurt"], label: "Nonfat Greek Yogurt", per100gCal: 59, per100gPro: 10.2, per100gCarb: 3.6, per100gFat: 0.4, per100gFiber: 0, per100gSugar: 3.2, defaultServingGrams: 170),
        FoodRef(aliases: ["protein shake", "protein powder", "whey"], label: "Whey Protein Isolate", per100gCal: 370, per100gPro: 83, per100gCarb: 3, per100gFat: 1.5, per100gFiber: 0, per100gSugar: 1.5, defaultServingGrams: 30),
        FoodRef(aliases: ["avocado"], label: "Avocado", per100gCal: 160, per100gPro: 2, per100gCarb: 8.5, per100gFat: 14.7, per100gFiber: 6.7, per100gSugar: 0.7, defaultServingGrams: 100),
        FoodRef(aliases: ["banana"], label: "Banana", per100gCal: 89, per100gPro: 1.1, per100gCarb: 22.8, per100gFat: 0.3, per100gFiber: 2.6, per100gSugar: 12.2, defaultServingGrams: 118),
        FoodRef(aliases: ["blueberries", "berries"], label: "Blueberries", per100gCal: 57, per100gPro: 0.7, per100gCarb: 14.5, per100gFat: 0.3, per100gFiber: 2.4, per100gSugar: 10, defaultServingGrams: 100),
        FoodRef(aliases: ["sweet potato"], label: "Baked Sweet Potato", per100gCal: 90, per100gPro: 2, per100gCarb: 20.7, per100gFat: 0.2, per100gFiber: 3.3, per100gSugar: 6.5, defaultServingGrams: 150),
        FoodRef(aliases: ["broccoli", "spinach", "greens", "salad"], label: "Broccoli / Greens", per100gCal: 34, per100gPro: 2.8, per100gCarb: 6.6, per100gFat: 0.4, per100gFiber: 2.6, per100gSugar: 1.7, defaultServingGrams: 120),
        FoodRef(aliases: ["olive oil", "butter"], label: "Extra Virgin Olive Oil", per100gCal: 884, per100gPro: 0, per100gCarb: 0, per100gFat: 100, per100gFiber: 0, per100gSugar: 0, defaultServingGrams: 14),
        FoodRef(aliases: ["almonds", "walnuts", "nuts"], label: "Mixed Nuts / Almonds", per100gCal: 579, per100gPro: 21.2, per100gCarb: 21.6, per100gFat: 49.9, per100gFiber: 12.5, per100gSugar: 4.4, defaultServingGrams: 28),
        FoodRef(aliases: ["sourdough", "bread", "toast"], label: "Sourdough Bread", per100gCal: 266, per100gPro: 9, per100gCarb: 52, per100gFat: 1.8, per100gFiber: 2.7, per100gSugar: 2.5, defaultServingGrams: 60),
        FoodRef(aliases: ["paneer", "tofu"], label: "Paneer / Cottage Cheese", per100gCal: 265, per100gPro: 18, per100gCarb: 3, per100gFat: 20, per100gFiber: 0, per100gSugar: 2, defaultServingGrams: 100)
    ]

    public static func parse(_ text: String) -> (matchedItems: [String], calories: Double, protein: Double, carbs: Double, fat: Double, fiber: Double, sugar: Double) {
        var working = text.lowercased()
        var matched: [String] = []
        var cal = 0.0, pro = 0.0, carb = 0.0, fat = 0.0, fib = 0.0, sug = 0.0

        for item in table {
            var matchedRange: Range<String.Index>? = nil
            var matchedQtyGrams: Double = item.defaultServingGrams

            for alias in item.aliases {
                let escaped = NSRegularExpression.escapedPattern(for: alias)
                let withQtyPattern = "(?:(\\d+(?:\\.\\d+)?)\\s*(?:(grams?|g|oz|tbsp|cups?|scoops?)\\b\\s*)?)?\\b\(escaped)\\b"
                if let regex = try? NSRegularExpression(pattern: withQtyPattern, options: []),
                   let m = regex.firstMatch(in: working, range: NSRange(working.startIndex..., in: working)),
                   let fullSwiftRange = Range(m.range, in: working) {
                    matchedRange = fullSwiftRange
                    if m.range(at: 1).location != NSNotFound,
                       let qtyRange = Range(m.range(at: 1), in: working),
                       let qty = Double(working[qtyRange]), qty > 0 {
                        let unitStr: String = {
                            guard m.range(at: 2).location != NSNotFound,
                                  let uRange = Range(m.range(at: 2), in: working) else { return "" }
                            return String(working[uRange])
                        }()
                        switch unitStr {
                        case "g", "gram", "grams":
                            matchedQtyGrams = qty
                        case "oz":
                            matchedQtyGrams = qty * 28.35
                        case "tbsp":
                            matchedQtyGrams = qty * 14.0
                        case "scoop", "scoops":
                            matchedQtyGrams = qty * 30.0
                        case "cup", "cups":
                            matchedQtyGrams = qty * 160.0
                        default:
                            matchedQtyGrams = qty * item.defaultServingGrams
                        }
                    }
                    break
                }
            }

            guard let usedRange = matchedRange else { continue }
            working.replaceSubrange(usedRange, with: " ")

            let factor = matchedQtyGrams / 100.0
            cal += item.per100gCal * factor
            pro += item.per100gPro * factor
            carb += item.per100gCarb * factor
            fat += item.per100gFat * factor
            fib += item.per100gFiber * factor
            sug += item.per100gSugar * factor
            matched.append("\(Int(matchedQtyGrams.rounded()))g \(item.label)")
        }

        return (matched, cal.rounded(), (pro * 10).rounded() / 10, (carb * 10).rounded() / 10, (fat * 10).rounded() / 10, (fib * 10).rounded() / 10, (sug * 10).rounded() / 10)
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
    @Published public var requestedToolSheet: String? = nil
    @Published public var shouldAutoStartDeadHang: Bool = false

    private init() {}

    public func openURL(_ url: URL) {
        guard url.scheme == "apex" else { return }
        let segs = url.pathComponents.dropFirst().map { $0.lowercased() }
        switch url.host {
        case "summary": selectedTab = 0
        case "face": selectedTab = 1
        case "train":
            selectedTab = 2
            if let ex = segs.first, !ex.isEmpty {
                requestedExerciseRaw = ex
            }
        case "nutrition", "fuel":
            selectedTab = 3
        case "longevity", "biology":
            selectedTab = 4
            if segs.contains("deadhang") {
                shouldAutoStartDeadHang = true
            } else if let tool = segs.first, !tool.isEmpty {
                requestedToolSheet = tool
            }
        default: break
        }
    }
}
#endif
