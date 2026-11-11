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
