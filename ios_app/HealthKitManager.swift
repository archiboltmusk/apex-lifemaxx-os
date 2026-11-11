import Foundation
import HealthKit
import Combine
import SwiftUI
import Network
import WidgetKit

public enum HealthConnectionState: Equatable {
    case needsPermission
    case connecting
    case connected
    case unavailable
}

public struct DiscoveredMacEndpoint: Identifiable, Equatable {
    public let id: String
    public let name: String
    public var host: String?
    public var port: Int?
    public var txtToken: String?
    public let nwEndpoint: NWEndpoint

    public static func == (lhs: DiscoveredMacEndpoint, rhs: DiscoveredMacEndpoint) -> Bool {
        lhs.id == rhs.id && lhs.host == rhs.host && lhs.port == rhs.port && lhs.txtToken == rhs.txtToken
    }
}

// MARK: - Native Apple HealthKit Telemetry, Baselines & Bonjour Continuity Engine
@MainActor
public class HealthKitManager: ObservableObject {
    public static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()

    // Clean Connection State (Never leaks raw developer errors)
    @Published public var isAvailable: Bool = false
    @Published public var connectionState: HealthConnectionState = .needsPermission
    @Published public var statusLabel: String = "Apple Health Ready"

    // Concentric Activity Rings Data (Real-Time Today from HKActivitySummary or Fallback Stats)
    @Published public var moveCalories: Double = 0
    @Published public var moveTarget: Double = 750
    @Published public var exerciseMinutes: Double = 0
    @Published public var exerciseTarget: Double = 30
    @Published public var standHours: Double = 0
    @Published public var standTarget: Double = 12
    @Published public var hasExactWatchSummary: Bool = false

    // Measured Latest Vitals
    @Published public var restingHeartRate: Double? = nil
    @Published public var heartRateVariability: Double? = nil
    @Published public var vo2Max: Double? = nil
    @Published public var sleepTotalHours: Double? = nil
    @Published public var dailySteps: Int = 0

    // Sleep Stage Architecture (Last Night)
    @Published public var sleepDeepHours: Double = 0
    @Published public var sleepRemHours: Double = 0
    @Published public var sleepCoreHours: Double = 0
    @Published public var sleepAwakeHours: Double = 0

    // Overnight Recovery & Body Composition Sensors
    @Published public var bloodOxygenPercent: Double? = nil
    @Published public var respiratoryRateBpm: Double? = nil
    @Published public var wristTempDeltaC: Double? = nil
    @Published public var bodyWeightKg: Double? = nil
    @Published public var bodyFatPercent: Double? = nil
    @Published public var leanBodyMassKg: Double? = nil

    // 7–60 Day Personal Rolling History & Baselines
    @Published public var hrvHistory: [DailyMetricPoint] = []
    @Published public var rhrHistory: [DailyMetricPoint] = []
    @Published public var vo2History: [DailyMetricPoint] = []
    @Published public var sleepHistory: [DailyMetricPoint] = []
    @Published public var moveHistory: [DailyMetricPoint] = []
    @Published public var weightHistory: [DailyMetricPoint] = []

    // Intraday Heart Rate, Stress & HealthKit / CGM Glucose Streams
    @Published public var intradayHeartRates: [HourlyMetricPoint] = []
    @Published public var glucoseSamples24h: [HourlyMetricPoint] = []
    @AppStorage("apex_sleep_goal_hours") public var baselineSleepGoalHours: Double = 7.75
    @AppStorage("apex_logged_nap_hours") public var loggedNapHoursToday: Double = 0
    @AppStorage("apex_logged_nap_day") private var loggedNapDayKey: String = ""
    @AppStorage("apex_strength_load_bonus") public var strengthStrainBonusToday: Double = 0
    @AppStorage("apex_strength_load_day") private var strengthLoadDayKey: String = ""
    @AppStorage("apex_offline_activity_day") private var offlineActivityDayKey: String = ""
    @AppStorage("apex_offline_move_kcal") private var offlineMoveKcalToday: Double = 0
    @AppStorage("apex_offline_ex_min") private var offlineExerciseMinToday: Double = 0

    // Biological & Clinical Epigenetic Age
    @AppStorage("apex_chronological_age") public var chronologicalAge: Double = 26.0
    @AppStorage("apex_age_manually_set") public var isAgeManuallySet: Bool = false
    @AppStorage("apex_mac_token") public var macSyncToken: String = ""
    @AppStorage("apex_clinical_phenoage") public var clinicalPhenoAgeValue: Double = 0
    @AppStorage("apex_clinical_phenoage_updated") public var clinicalPhenoAgeDateStr: String = ""
    @AppStorage("apex_hk_authorized") private var wasHKAuthorized: Bool = false

    // Mac Companion Continuity & Bonjour Auto-Discovery
    @AppStorage("apex_mac_host") public var macHost: String = "127.0.0.1"
    @AppStorage("apex_mac_port") public var macServerPort: Int = 60159
    @AppStorage("apex_mac_name") public var macDeviceName: String = "Local Mac"
    @AppStorage("apex_sync_enabled") public var isSyncingToMac: Bool = true
    @Published public var isMacReachable: Bool = false
    @Published public var lastSyncTimestamp: Date? = nil
    @Published public var discoveredMacs: [DiscoveredMacEndpoint] = []

    private var observerQueries: [HKObserverQuery] = []
    private var bonjourBrowser: NWBrowser? = nil

    public var isAuthorized: Bool {
        connectionState == .connected
    }

    public var clinicalPhenoAge: Double? {
        clinicalPhenoAgeValue > 0 ? clinicalPhenoAgeValue : nil
    }

    // 7-Day HRV Personal Baseline & Delta %
    public var hrvBaseline7d: Double? {
        let recent = Array(hrvHistory.suffix(7))
        guard recent.count >= 2 else { return nil }
        let sum = recent.reduce(0.0) { $0 + $1.value }
        return sum / Double(recent.count)
    }

    public var hrvDeltaPercent: Int? {
        guard let current = heartRateVariability, let base = hrvBaseline7d, base > 1 else { return nil }
        return Int((((current - base) / base) * 100.0).rounded())
    }

    // 7-Day Resting HR Personal Baseline & Delta bpm
    public var rhrBaseline7d: Double? {
        let recent = Array(rhrHistory.suffix(7))
        guard recent.count >= 2 else { return nil }
        let sum = recent.reduce(0.0) { $0 + $1.value }
        return sum / Double(recent.count)
    }

    public var rhrDeltaBpm: Int? {
        guard let current = restingHeartRate, let base = rhrBaseline7d else { return nil }
        return Int((current - base).rounded())
    }

    public var sleepEfficiencyPercent: Int? {
        let asleep = sleepDeepHours + sleepRemHours + sleepCoreHours
        let total = asleep + sleepAwakeHours
        guard total > 0.25 else { return nil }
        return Int(min(100, (asleep / total * 100.0).rounded()))
    }

    // Derived Autonomic Readiness (0–100) using Personal Baselines when available
    public var readinessScore: Int? {
        guard restingHeartRate != nil || heartRateVariability != nil || sleepTotalHours != nil else {
            return nil
        }
        var score = 78.0
        if let deltaPct = hrvDeltaPercent {
            score += min(16.0, max(-18.0, Double(deltaPct) * 0.45))
        } else if let hrv = heartRateVariability {
            score += min(15.0, max(-15.0, (hrv - 55.0) * 0.35))
        }

        if let rhrDiff = rhrDeltaBpm {
            score -= min(12.0, max(-10.0, Double(rhrDiff) * 2.2))
        } else if let rhr = restingHeartRate {
            score += min(10.0, max(-12.0, (62.0 - rhr) * 0.5))
        }

        if let sleep = sleepTotalHours {
            if sleep >= 7.5 { score += 5.0 }
            else if sleep < 6.0 { score -= 10.0 }
        }
        if let resp = respiratoryRateBpm, resp > 18.5 {
            score -= 4.0
        }
        return Int(max(20, min(99, score.rounded())))
    }

    // Derived Biological Fitness Age (Vitals Composite)
    public var biologicalAge: Double? {
        guard restingHeartRate != nil || heartRateVariability != nil || vo2Max != nil || moveCalories > 0 else {
            return nil
        }
        var delta = 0.0
        if let vo2 = vo2Max { delta -= (vo2 - 42.0) * 0.42 }
        if let rhr = restingHeartRate { delta += (rhr - 60.0) * 0.22 }
        if let hrv = heartRateVariability { delta -= (hrv - 52.0) * 0.11 }
        if let sleep = sleepTotalHours {
            if sleep >= 7.5 && sleep <= 9.0 { delta -= 1.2 }
            else if sleep < 6.0 { delta += 1.8 }
        }
        if dailySteps > 0 {
            delta -= (Double(dailySteps - 8000) / 2500.0) * 0.5
        }
        let bio = chronologicalAge + delta
        return max(18.0, (bio * 10).rounded() / 10)
    }

    public var paceOfAging: Double? {
        ApexBiometricMath.paceOfAging(
            chronologicalAge: chronologicalAge,
            biologicalAge: biologicalAge,
            clinicalPhenoAge: clinicalPhenoAge,
            hrv: heartRateVariability,
            hrvBaseline: hrvBaseline7d,
            rhr: restingHeartRate,
            rhrBaseline: rhrBaseline7d,
            vo2Max: vo2Max,
            sleepEfficiencyPercent: sleepEfficiencyPercent
        )
    }

    public static func currentDayKey() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    public func ensureDailyCountersAreCurrent() {
        let today = Self.currentDayKey()
        if loggedNapDayKey != today {
            loggedNapDayKey = today
            loggedNapHoursToday = 0
        }
        if strengthLoadDayKey != today {
            strengthLoadDayKey = today
            strengthStrainBonusToday = 0
        }
        if offlineActivityDayKey != today {
            offlineActivityDayKey = today
            offlineMoveKcalToday = 0
            offlineExerciseMinToday = 0
        }
    }

    public func addNapMinutes(_ minutes: Double) {
        ensureDailyCountersAreCurrent()
        loggedNapHoursToday = min(3.0, loggedNapHoursToday + max(0, minutes / 60.0))
        persistWidgetSnapshot()
        broadcastToMac()
    }

    public func addStrengthStrainBonus(_ delta: Double) {
        ensureDailyCountersAreCurrent()
        strengthStrainBonusToday = min(8.0, strengthStrainBonusToday + max(0, delta))
        persistWidgetSnapshot()
        broadcastToMac()
    }

    // MARK: - Bevel Pro Engine: Strain (0–21), Adaptive Target, Intraday Stress, Energy Bank & Sleep Coach
    public var todayStrainScore: Double? {
        ApexBiometricMath.dailyStrain(
            moveKcal: moveCalories,
            exerciseMinutes: exerciseMinutes,
            strengthSetsBonus: strengthStrainBonusToday
        )
    }

    public var targetStrainRange: ClosedRange<Double>? {
        ApexBiometricMath.targetStrainRange(readiness: readinessScore)
    }

    public var stressHourlyCurve: [HourlyMetricPoint] {
        guard !intradayHeartRates.isEmpty else { return [] }
        let rhr = restingHeartRate ?? 60.0
        let maxHR = max(145.0, 220.0 - chronologicalAge)
        let reserve = max(35.0, maxHR - rhr)
        let hrvMod: Double = {
            guard let pct = hrvDeltaPercent else { return 0 }
            return Double(-pct) * 0.25
        }()

        let cal = Calendar.current
        var buckets: [Int: [Double]] = [:]
        for pt in intradayHeartRates {
            let hr = pt.value
            let hour = cal.component(.hour, from: pt.date)
            let hrrRatio = max(0.0, min(1.0, (hr - rhr) / reserve))
            let score = max(5.0, min(98.0, hrrRatio * 105.0 + 16.0 + hrvMod))
            buckets[hour, default: []].append(score)
        }

        let todayStart = cal.startOfDay(for: Date())
        return buckets.keys.sorted().compactMap { hour in
            guard let vals = buckets[hour], !vals.isEmpty,
                  let dt = cal.date(byAdding: .hour, value: hour, to: todayStart) else { return nil }
            let mean = vals.reduce(0, +) / Double(vals.count)
            return HourlyMetricPoint(date: dt, value: mean.rounded(), label: "\(hour):00")
        }
    }

    public var currentStressScore: Int? {
        if let last = stressHourlyCurve.last {
            return Int(last.value.rounded())
        }
        guard let hrv = heartRateVariability, let rhr = restingHeartRate else { return nil }
        // Single-point autonomic estimate when only latest HRV + RHR exist (no intraday HR curve)
        let base = 42.0 + (rhr - 58.0) * 1.1 - (hrv - 55.0) * 0.35
        return Int(max(8, min(95, base.rounded())))
    }

    public var energyBankCurve: [HourlyMetricPoint] {
        guard let startBattery = readinessScore else { return [] }
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let wakeMin = UserDefaults.standard.object(forKey: "apex_wake_minutes") as? Int ?? 390
        let wakeHour = max(4, min(12, wakeMin / 60))
        let currentHour = max(wakeHour, cal.component(.hour, from: Date()))
        var battery = Double(startBattery)
        let hourlyStress = Dictionary(uniqueKeysWithValues: stressHourlyCurve.map { (cal.component(.hour, from: $0.date), $0.value) })
        let hoursAwake = max(1.0, Double(currentHour - wakeHour))
        let activeDrainPerHour = min(4.8, (moveCalories / 150.0) / hoursAwake)

        var curve: [HourlyMetricPoint] = []
        let napApplyHour = max(wakeHour + 1, min(16, currentHour))
        for h in wakeHour...currentHour {
            guard let dt = cal.date(byAdding: .hour, value: h, to: todayStart) else { continue }
            if h > wakeHour {
                let stressAtH = hourlyStress[h] ?? 28.0
                let drain = activeDrainPerHour + max(0.3, (stressAtH - 18.0) * 0.08)
                battery = max(5.0, battery - drain)
                if loggedNapHoursToday > 0 && h == napApplyHour {
                    battery = min(98.0, battery + loggedNapHoursToday * 18.0)
                }
            }
            curve.append(HourlyMetricPoint(date: dt, value: battery.rounded(), label: "\(h):00"))
        }
        return curve
    }

    public var energyBankPercent: Int? {
        guard readinessScore != nil else { return nil }
        if let last = energyBankCurve.last {
            return Int(last.value.rounded())
        }
        return readinessScore
    }

    public var sleepDebtHours: Double? {
        let recent = Array(sleepHistory.suffix(7))
        guard !recent.isEmpty else { return nil }
        let target = baselineSleepGoalHours
        var debt = 0.0
        for (idx, pt) in recent.enumerated() {
            let weight = Double(idx + 1) / Double(recent.count)
            let diff = max(0.0, target - pt.value)
            debt += diff * (0.4 + 0.6 * weight) / Double(recent.count) * 3.0
        }
        return (min(6.0, max(0.0, debt)) * 10).rounded() / 10
    }

    public var sleepNeededHours: Double? {
        guard sleepTotalHours != nil || !sleepHistory.isEmpty || readinessScore != nil else { return nil }
        let strainNeed = (todayStrainScore ?? 0) * 0.035
        let debtRecover = (sleepDebtHours ?? 0) * 0.35
        let napCredit = min(1.2, loggedNapHoursToday)
        let needed = max(6.5, min(10.5, baselineSleepGoalHours + strainNeed + debtRecover - napCredit))
        return (needed * 10).rounded() / 10
    }

    public var vitalRangeSummary: (inRange: Int, total: Int, items: [(name: String, value: String, inRange: Bool, note: String)]) {
        var rows: [(String, String, Bool, String)] = []
        if let rhr = restingHeartRate {
            let baseline = rhrBaseline7d ?? rhr
            let ok = abs(rhr - baseline) <= 5.5
            rows.append(("Resting HR", "\(Int(rhr.rounded())) bpm", ok, ok ? "Within baseline" : "Above 7d baseline"))
        }
        if let hrv = heartRateVariability {
            let baseline = hrvBaseline7d ?? hrv
            let pct = baseline > 1 ? ((hrv - baseline) / baseline) * 100.0 : 0
            let ok = pct >= -18.0
            rows.append(("HRV SDNN", "\(Int(hrv.rounded())) ms", ok, ok ? "Normal vagal tone" : "Suppressed vs baseline"))
        }
        if let resp = respiratoryRateBpm {
            let ok = resp >= 11.0 && resp <= 19.5
            rows.append(("Respiratory Rate", String(format: "%.1f /m", resp), ok, ok ? "Steady" : "Elevated"))
        }
        if let temp = wristTempDeltaC {
            let ok = temp >= -0.6 && temp <= 0.6
            rows.append(("Wrist Temp", String(format: "%+.2f °C", temp), ok, ok ? "Nominal" : "Thermal shift"))
        }
        if let spo2 = bloodOxygenPercent {
            let ok = spo2 >= 94.0
            rows.append(("Blood Oxygen", "\(Int(spo2.rounded()))%", ok, ok ? "Normal SpO₂" : "Below 94%"))
        }
        let inRange = rows.filter { $0.2 }.count
        return (inRange, rows.count, rows)
    }

    private init() {
        self.isAvailable = HKHealthStore.isHealthDataAvailable()
        ensureDailyCountersAreCurrent()
        loadPersistedLocalFallbacks()
        if isAvailable {
            if wasHKAuthorized {
                self.connectionState = .connected
                self.statusLabel = "Live HealthKit"
            } else {
                self.connectionState = .needsPermission
                self.statusLabel = "Connect Apple Health"
            }
        } else {
            self.connectionState = .unavailable
            self.statusLabel = "On-Device Storage"
        }
        startBonjourDiscovery()
        persistWidgetSnapshot()
    }

    // MARK: - Request Apple Health Permission
    public func requestAuthorization() {
        guard isAvailable else {
            connectionState = .unavailable
            statusLabel = "Health Data Unavailable"
            return
        }

        var readTypes = Set<HKObjectType>()
        readTypes.insert(HKObjectType.activitySummaryType())
        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
            readTypes.insert(mindful)
        }
        if let standCat = HKObjectType.categoryType(forIdentifier: .appleStandHour) {
            readTypes.insert(standCat)
        }

        var quantityIds: [HKQuantityTypeIdentifier] = [
            .activeEnergyBurned,
            .appleExerciseTime,
            .appleStandTime,
            .stepCount,
            .heartRate,
            .restingHeartRate,
            .heartRateVariabilitySDNN,
            .vo2Max,
            .oxygenSaturation,
            .respiratoryRate,
            .bodyMass,
            .bodyFatPercentage,
            .leanBodyMass,
            .bloodGlucose,
            .dietaryEnergyConsumed,
            .dietaryProtein,
            .dietaryCarbohydrates,
            .dietaryFatTotal,
            .dietaryFiber,
            .dietarySugar,
            .dietarySodium,
            .dietaryWater,
            .dietaryCaffeine
        ]
        if #available(iOS 16.0, *) {
            quantityIds.append(.appleSleepingWristTemperature)
        }
        for id in quantityIds {
            if let q = HKObjectType.quantityType(forIdentifier: id) {
                readTypes.insert(q)
            }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(sleep)
        }
        if let dob = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) {
            readTypes.insert(dob)
        }

        let shareQuantityIds: [HKQuantityTypeIdentifier] = [
            .activeEnergyBurned,
            .appleExerciseTime,
            .heartRate,
            .heartRateVariabilitySDNN,
            .bloodGlucose,
            .dietaryEnergyConsumed,
            .dietaryProtein,
            .dietaryCarbohydrates,
            .dietaryFatTotal,
            .dietaryFiber,
            .dietarySugar,
            .dietarySodium,
            .dietaryWater,
            .dietaryCaffeine
        ]
        var shareTypes = Set<HKSampleType>()
        for id in shareQuantityIds {
            if let qtyType = HKObjectType.quantityType(forIdentifier: id) {
                shareTypes.insert(qtyType)
            }
        }
        shareTypes.insert(HKObjectType.workoutType())
        if let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
            shareTypes.insert(mindfulType)
        }

        connectionState = .connecting
        statusLabel = "Connecting..."

        healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { [weak self] success, _ in
            Task { @MainActor in
                guard let self = self else { return }
                if success {
                    self.wasHKAuthorized = true
                    self.connectionState = .connected
                    self.statusLabel = "Live HealthKit"
                    self.startRealtimeObserverQueries()
                    self.fetchLiveHealthMetrics()
                } else {
                    self.connectionState = .needsPermission
                    self.statusLabel = "Permission Required"
                }
            }
        }
    }

    // MARK: - Background Observer Queries
    public func startRealtimeObserverQueries() {
        guard isAvailable else { return }

        let sampleTypes: [HKQuantityTypeIdentifier] = [
            .activeEnergyBurned,
            .appleExerciseTime,
            .appleStandTime,
            .stepCount,
            .heartRate,
            .heartRateVariabilitySDNN
        ]

        for identifier in sampleTypes {
            guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else { continue }

            let query = HKObserverQuery(sampleType: quantityType, predicate: nil) { [weak self] _, completionHandler, error in
                if error == nil {
                    Task { @MainActor in
                        self?.fetchLiveHealthMetrics()
                    }
                }
                completionHandler()
            }

            healthStore.execute(query)
            observerQueries.append(query)
            healthStore.enableBackgroundDelivery(for: quantityType, frequency: .immediate) { _, _ in }
        }
    }

    // MARK: - Fetch Real ActivitySummary, Sleep Architecture, Vitals & 7-Day Baselines
    public func fetchLiveHealthMetrics() {
        ensureDailyCountersAreCurrent()
        guard isAvailable else { return }

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let todayPredicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        // 0. Chronological DOB from Apple Health (unless manually overridden)
        fetchChronologicalAgeFromHealthKit()

        // 1. Exact Apple Watch Activity Rings (HKActivitySummaryQuery)
        var dateComponents = calendar.dateComponents([.era, .year, .month, .day], from: now)
        dateComponents.calendar = calendar
        let summaryPredicate = HKQuery.predicateForActivitySummary(with: dateComponents)
        let activityQuery = HKActivitySummaryQuery(predicate: summaryPredicate) { [weak self] _, summaries, _ in
            Task { @MainActor in
                guard let self = self else { return }
                if let summary = summaries?.first {
                    self.hasExactWatchSummary = true
                    let move = summary.activeEnergyBurned.doubleValue(for: .kilocalorie())
                    let moveGoal = max(100, summary.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie()))
                    let ex = summary.appleExerciseTime.doubleValue(for: .minute())
                    let exGoal = max(5, summary.appleExerciseTimeGoal.doubleValue(for: .minute()))
                    let stand = summary.appleStandHours.doubleValue(for: .count())
                    let standGoal = max(4, summary.appleStandHoursGoal.doubleValue(for: .count()))

                    self.moveCalories = max(move, self.offlineMoveKcalToday)
                    self.moveTarget = moveGoal
                    self.exerciseMinutes = max(ex, self.offlineExerciseMinToday)
                    self.exerciseTarget = exGoal
                    self.standHours = stand
                    self.standTarget = standGoal
                    if self.connectionState != .connected {
                        self.connectionState = .connected
                        self.statusLabel = "Live HealthKit"
                        self.wasHKAuthorized = true
                    }
                    self.persistWidgetSnapshot()
                    self.broadcastToMac()
                } else {
                    self.fetchFallbackRingQuantities()
                }
            }
        }
        healthStore.execute(activityQuery)

        // 2. Daily Steps
        if let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) {
            let query = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: todayPredicate, options: .cumulativeSum) { [weak self] _, stats, _ in
                let count = Int(stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                Task { @MainActor in
                    self?.dailySteps = count
                    self?.persistWidgetSnapshot()
                }
            }
            healthStore.execute(query)
        }

        // 3. 60-Day Resting HR Samples & Latest (7d baseline + Biology long-term trend)
        fetchRecentSamples(
            identifier: .restingHeartRate,
            unit: HKUnit(from: "count/min"),
            daysBack: 60
        ) { [weak self] points in
            guard let self = self else { return }
            self.rhrHistory = points
            self.restingHeartRate = points.last?.value
            self.persistWidgetSnapshot()
            self.broadcastToMac()
        }

        // 4. 60-Day HRV (SDNN) Samples & Latest (7d baseline + Biology long-term trend)
        fetchRecentSamples(
            identifier: .heartRateVariabilitySDNN,
            unit: .secondUnit(with: .milli),
            daysBack: 60
        ) { [weak self] points in
            guard let self = self else { return }
            self.hrvHistory = points
            self.heartRateVariability = points.last?.value
            self.persistWidgetSnapshot()
            self.broadcastToMac()
        }

        // 5. 60-Day Weight & VO2 Max + Body Composition
        fetchRecentSamples(identifier: .vo2Max, unit: HKUnit(from: "ml/kg*min"), daysBack: 60) { [weak self] points in
            guard let self = self else { return }
            self.vo2History = Array(points.suffix(14))
            self.vo2Max = points.last?.value
            self.persistWidgetSnapshot()
        }
        fetchRecentSamples(identifier: .bodyMass, unit: .gramUnit(with: .kilo), daysBack: 60) { [weak self] points in
            self?.weightHistory = points
            self?.bodyWeightKg = points.last?.value
        }
        fetchLatestQuantity(identifier: .bodyFatPercentage, unit: .percent()) { [weak self] val in
            self?.bodyFatPercent = val.map { ($0 * 1000).rounded() / 10 }
        }
        fetchLatestQuantity(identifier: .leanBodyMass, unit: .gramUnit(with: .kilo)) { [weak self] val in
            self?.leanBodyMassKg = val.map { ($0 * 10).rounded() / 10 }
        }

        // 6. Overnight Oxygen Saturation, Respiratory Rate & Wrist Temp
        fetchLatestQuantity(identifier: .oxygenSaturation, unit: .percent()) { [weak self] val in
            self?.bloodOxygenPercent = val.map { min(100.0, ($0 * 100.0).rounded()) }
        }
        fetchLatestQuantity(identifier: .respiratoryRate, unit: HKUnit(from: "count/min")) { [weak self] val in
            self?.respiratoryRateBpm = val.map { ($0 * 10).rounded() / 10 }
        }
        if #available(iOS 16.0, *) {
            fetchLatestQuantity(identifier: .appleSleepingWristTemperature, unit: .degreeCelsius()) { [weak self] val in
                self?.wristTempDeltaC = val.map { ($0 * 100).rounded() / 100 }
            }
        }

        // 7. 7-Day Active Energy Collection, Intraday Today HR (Stress Engine) & 24h Blood Glucose (CGM)
        fetch7DayCumulativeCollection(identifier: .activeEnergyBurned, unit: .kilocalorie()) { [weak self] points in
            self?.moveHistory = points
        }
        fetchIntradaySamplesToday(identifier: .heartRate, unit: HKUnit(from: "count/min")) { [weak self] points in
            self?.intradayHeartRates = points
            self?.persistWidgetSnapshot()
        }
        fetchRecent24hGlucose()

        // 8. 7-Day Sleep Stage Architecture & Last Night Summary
        fetchSleepArchitecture(calendar: calendar, now: now)
    }

    private func fetchFallbackRingQuantities() {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let todayPredicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        if let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: todayPredicate, options: .cumulativeSum) { [weak self] _, stats, _ in
                let kcal = stats?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                Task { @MainActor in
                    guard let self = self else { return }
                    self.moveCalories = max(kcal, self.offlineMoveKcalToday)
                    if kcal > 0, self.connectionState != .connected {
                        self.connectionState = .connected
                        self.statusLabel = "Live HealthKit"
                        self.wasHKAuthorized = true
                    }
                    self.persistWidgetSnapshot()
                    self.broadcastToMac()
                }
            }
            healthStore.execute(query)
        }
        if let exType = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) {
            let query = HKStatisticsQuery(quantityType: exType, quantitySamplePredicate: todayPredicate, options: .cumulativeSum) { [weak self] _, stats, _ in
                let mins = stats?.sumQuantity()?.doubleValue(for: .minute()) ?? 0
                Task { @MainActor in
                    guard let self = self else { return }
                    self.exerciseMinutes = max(mins, self.offlineExerciseMinToday)
                    self.persistWidgetSnapshot()
                }
            }
            healthStore.execute(query)
        }
        if let standCatType = HKObjectType.categoryType(forIdentifier: .appleStandHour) {
            let query = HKSampleQuery(sampleType: standCatType, predicate: todayPredicate, limit: 48, sortDescriptors: nil) { [weak self] _, samples, _ in
                let catSamples = (samples as? [HKCategorySample]) ?? []
                let cal = Calendar.current
                var stoodHours = Set<Int>()
                for s in catSamples where s.value == HKCategoryValueAppleStandHour.stood.rawValue {
                    stoodHours.insert(cal.component(.hour, from: s.startDate))
                }
                Task { @MainActor in
                    guard let self = self else { return }
                    if !stoodHours.isEmpty {
                        self.standHours = Double(stoodHours.count)
                        self.persistWidgetSnapshot()
                    }
                }
            }
            healthStore.execute(query)
        } else if let standType = HKObjectType.quantityType(forIdentifier: .appleStandTime) {
            let query = HKStatisticsQuery(quantityType: standType, quantitySamplePredicate: todayPredicate, options: .cumulativeSum) { [weak self] _, stats, _ in
                let mins = stats?.sumQuantity()?.doubleValue(for: .minute()) ?? 0
                Task { @MainActor in
                    self?.standHours = min(24.0, (mins / 60.0 * 10.0).rounded() / 10.0)
                    self?.persistWidgetSnapshot()
                }
            }
            healthStore.execute(query)
        }
    }

    private func fetchChronologicalAgeFromHealthKit() {
        guard isAvailable, !isAgeManuallySet else { return }
        if let dobComponents = try? healthStore.dateOfBirthComponents(),
           let birthDate = Calendar.current.date(from: dobComponents) {
            let years = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year
            if let years, (16...105).contains(years) {
                self.chronologicalAge = Double(years)
                self.persistWidgetSnapshot()
            }
        }
    }

    // MARK: - Dietary Intake & Glucose HealthKit Writers + Intraday Queries
    public func logNutritionToHealth(
        calories: Double,
        proteinG: Double,
        carbsG: Double,
        fatG: Double,
        fiberG: Double = 0,
        sugarG: Double = 0,
        sodiumMg: Double = 0,
        waterMl: Double = 0,
        caffeineMg: Double = 0,
        date: Date = Date()
    ) async {
        guard isAvailable else { return }
        var samples: [HKQuantitySample] = []

        func addSample(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit, _ val: Double) {
            guard val > 0, let type = HKQuantityType.quantityType(forIdentifier: id) else { return }
            samples.append(HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: val), start: date, end: date))
        }

        addSample(.dietaryEnergyConsumed, .kilocalorie(), calories)
        addSample(.dietaryProtein, .gram(), proteinG)
        addSample(.dietaryCarbohydrates, .gram(), carbsG)
        addSample(.dietaryFatTotal, .gram(), fatG)
        addSample(.dietaryFiber, .gram(), fiberG)
        addSample(.dietarySugar, .gram(), sugarG)
        addSample(.dietarySodium, .gramUnit(with: .milli), sodiumMg)
        addSample(.dietaryWater, .literUnit(with: .milli), waterMl)
        addSample(.dietaryCaffeine, .gramUnit(with: .milli), caffeineMg)

        if !samples.isEmpty {
            try? await healthStore.save(samples)
        }
    }

    private let manualGlucoseStorageKey = "apex_ios_manual_glucose_v1"

    private func loadPersistedLocalFallbacks() {
        ensureDailyCountersAreCurrent()
        if moveCalories == 0 && offlineMoveKcalToday > 0 {
            moveCalories = offlineMoveKcalToday
        }
        if exerciseMinutes == 0 && offlineExerciseMinToday > 0 {
            exerciseMinutes = offlineExerciseMinToday
        }
        if let data = UserDefaults.standard.data(forKey: manualGlucoseStorageKey),
           let decoded = try? JSONDecoder().decode([HourlyMetricPoint].self, from: data) {
            let cutoff = Date().addingTimeInterval(-86400)
            glucoseSamples24h = decoded.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
        }
    }

    private func saveManualGlucose(_ points: [HourlyMetricPoint]) {
        let cutoff = Date().addingTimeInterval(-86400)
        let recent = Array(points.filter { $0.date >= cutoff }.suffix(120))
        if let data = try? JSONEncoder().encode(recent) {
            UserDefaults.standard.set(data, forKey: manualGlucoseStorageKey)
        }
    }

    public func logGlucoseToHealth(mgPerDl: Double, date: Date = Date()) async {
        guard mgPerDl >= 30, mgPerDl <= 500 else { return }
        let unit = HKUnit(from: "mg/dL")
        if isAvailable, let type = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) {
            let sample = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: mgPerDl), start: date, end: date)
            try? await healthStore.save([sample])
        }
        let point = HourlyMetricPoint(date: date, value: mgPerDl.rounded(), label: date.formatted(date: .omitted, time: .shortened))
        glucoseSamples24h.append(point)
        glucoseSamples24h.sort { $0.date < $1.date }

        var existingManual: [HourlyMetricPoint] = []
        if let data = UserDefaults.standard.data(forKey: manualGlucoseStorageKey),
           let decoded = try? JSONDecoder().decode([HourlyMetricPoint].self, from: data) {
            existingManual = decoded
        }
        existingManual.append(point)
        saveManualGlucose(existingManual)
        syncEventToMac(extraPayload: ["glucoseLatest": mgPerDl])
    }

    public func logMindfulSession(minutes: Double) async -> Bool {
        guard isAvailable,
              minutes >= 0.5,
              let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            return false
        }
        let end = Date()
        let start = end.addingTimeInterval(-minutes * 60.0)
        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: start,
            end: end
        )
        do {
            try await healthStore.save([sample])
            syncEventToMac(extraPayload: ["mindfulMinutesLogged": (minutes * 10).rounded() / 10])
            return true
        } catch {
            return false
        }
    }

    private func fetchIntradaySamplesToday(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        completion: @escaping ([HourlyMetricPoint]) -> Void
    ) {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return }
        let cal = Calendar.current
        let now = Date()
        let start = cal.startOfDay(for: now)
        let pred = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
            let pts = (samples as? [HKQuantitySample] ?? []).map { s in
                HourlyMetricPoint(
                    date: s.startDate,
                    value: s.quantity.doubleValue(for: unit),
                    label: s.startDate.formatted(date: .omitted, time: .shortened)
                )
            }
            Task { @MainActor in completion(pts) }
        }
        healthStore.execute(query)
    }

    public func fetchRecent24hGlucose() {
        guard isAvailable, let type = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else { return }
        let unit = HKUnit(from: "mg/dL")
        let now = Date()
        let start = Calendar.current.date(byAdding: .hour, value: -24, to: now) ?? now
        let pred = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: type, predicate: pred, limit: 300, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            let pts = (samples as? [HKQuantitySample] ?? []).map { s in
                HourlyMetricPoint(
                    date: s.startDate,
                    value: s.quantity.doubleValue(for: unit).rounded(),
                    label: s.startDate.formatted(date: .omitted, time: .shortened)
                )
            }
            Task { @MainActor in
                guard let self = self else { return }
                var combined = pts
                if let data = UserDefaults.standard.data(forKey: self.manualGlucoseStorageKey),
                   let manual = try? JSONDecoder().decode([HourlyMetricPoint].self, from: data) {
                    let cutoff = Date().addingTimeInterval(-86400)
                    for m in manual where m.date >= cutoff {
                        if !combined.contains(where: { abs($0.date.timeIntervalSince(m.date)) < 60 && abs($0.value - m.value) < 2 }) {
                            combined.append(m)
                        }
                    }
                }
                if !combined.isEmpty {
                    self.glucoseSamples24h = combined.sorted { $0.date < $1.date }
                }
            }
        }
        healthStore.execute(query)
    }

    public func saveHeartRateToHealth(bpm: Double, hrvMs: Double? = nil) async {
        guard isAvailable, bpm >= 35, bpm <= 220 else { return }
        let now = Date()
        var samples: [HKQuantitySample] = []

        if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            let qty = HKQuantity(unit: HKUnit(from: "count/min"), doubleValue: bpm)
            samples.append(HKQuantitySample(type: hrType, quantity: qty, start: now, end: now))
        }
        if let hrv = hrvMs, hrv >= 5, hrv <= 250,
           let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            let qty = HKQuantity(unit: .secondUnit(with: .milli), doubleValue: hrv)
            samples.append(HKQuantitySample(type: hrvType, quantity: qty, start: now, end: now))
        }

        guard !samples.isEmpty else { return }
        try? await healthStore.save(samples)
        if let hrv = hrvMs {
            self.heartRateVariability = hrv
        }
        self.persistWidgetSnapshot()
        self.syncEventToMac(extraPayload: [
            "liveBpm": Int(bpm.rounded()),
            "liveHrvMs": Int((hrvMs ?? 0).rounded())
        ])
    }

    private func fetchLatestQuantity(identifier: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double?) -> Void) {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            let val = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
            Task { @MainActor in
                completion(val)
            }
        }
        healthStore.execute(query)
    }

    private func fetch7DayDiscreteSamples(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        completion: @escaping ([DailyMetricPoint]) -> Void
    ) {
        fetchRecentSamples(identifier: identifier, unit: unit, daysBack: 7, completion: completion)
    }

    private func fetchRecentSamples(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        daysBack: Int,
        completion: @escaping ([DailyMetricPoint]) -> Void
    ) {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return }
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(byAdding: .day, value: -daysBack, to: calendar.startOfDay(for: now)) ?? now
        let pred = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
            guard let qtySamples = samples as? [HKQuantitySample], !qtySamples.isEmpty else {
                Task { @MainActor in completion([]) }
                return
            }

            // Bucket daily means preserving chronological order
            var buckets: [Date: [Double]] = [:]
            for s in qtySamples {
                let day = calendar.startOfDay(for: s.startDate)
                buckets[day, default: []].append(s.quantity.doubleValue(for: unit))
            }

            let points = buckets.keys.sorted().map { day -> DailyMetricPoint in
                let vals = buckets[day] ?? [0]
                let avg = vals.reduce(0, +) / Double(vals.count)
                return DailyMetricPoint(date: day, value: (avg * 10).rounded() / 10)
            }

            Task { @MainActor in
                completion(points)
            }
        }
        healthStore.execute(query)
    }

    private func fetch7DayCumulativeCollection(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        completion: @escaping ([DailyMetricPoint]) -> Void
    ) {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return }
        let calendar = Calendar.current
        let now = Date()
        let anchor = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -6, to: anchor) ?? anchor
        let interval = DateComponents(day: 1)

        let query = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: anchor,
            intervalComponents: interval
        )
        query.initialResultsHandler = { _, results, _ in
            var points: [DailyMetricPoint] = []
            results?.enumerateStatistics(from: start, to: now) { stats, _ in
                let val = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                points.append(DailyMetricPoint(date: stats.startDate, value: val))
            }
            Task { @MainActor in
                completion(points)
            }
        }
        healthStore.execute(query)
    }

    private func fetchSleepArchitecture(calendar: Calendar, now: Date) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: calendar.startOfDay(for: now)) ?? now
        let pred = HKQuery.predicateForSamples(withStart: twoWeeksAgo, end: now, options: .strictStartDate)

        let query = HKSampleQuery(sampleType: sleepType, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, _ in
            guard let categorySamples = samples as? [HKCategorySample], !categorySamples.isEmpty else { return }

            let lastNightCutoff = calendar.date(byAdding: .hour, value: -24, to: now) ?? now
            var deep: TimeInterval = 0
            var rem: TimeInterval = 0
            var core: TimeInterval = 0
            var awake: TimeInterval = 0
            var unspecified: TimeInterval = 0

            // Group sleep durations by wake day for 7-day trend chart
            var nightlySeconds: [Date: TimeInterval] = [:]

            for s in categorySamples {
                let dur = s.endDate.timeIntervalSince(s.startDate)
                guard dur > 0 else { continue }

                let val = s.value
                let isAwake = (val == HKCategoryValueSleepAnalysis.awake.rawValue || val == HKCategoryValueSleepAnalysis.inBed.rawValue)

                if !isAwake {
                    let wakeDay = calendar.startOfDay(for: s.endDate)
                    nightlySeconds[wakeDay, default: 0] += dur
                }

                if s.endDate >= lastNightCutoff {
                    if #available(iOS 16.0, *) {
                        switch val {
                        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                            deep += dur
                        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                            rem += dur
                        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                            core += dur
                        case HKCategoryValueSleepAnalysis.awake.rawValue:
                            awake += dur
                        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                            unspecified += dur
                        default:
                            break
                        }
                    } else if !isAwake {
                        unspecified += dur
                    } else if val == HKCategoryValueSleepAnalysis.awake.rawValue {
                        awake += dur
                    }
                }
            }

            let totalAsleepSec = deep + rem + core + unspecified
            let points = nightlySeconds.keys.sorted().map { day in
                DailyMetricPoint(date: day, value: ((nightlySeconds[day] ?? 0) / 3600.0 * 10).rounded() / 10)
            }

            Task { @MainActor in
                guard let self = self else { return }
                self.sleepHistory = points
                if totalAsleepSec > 0 {
                    self.sleepDeepHours = deep / 3600.0
                    self.sleepRemHours = rem / 3600.0
                    self.sleepCoreHours = (core + unspecified) / 3600.0
                    self.sleepAwakeHours = awake / 3600.0
                    self.sleepTotalHours = totalAsleepSec / 3600.0
                }
                self.persistWidgetSnapshot()
                self.broadcastToMac()
            }
        }
        healthStore.execute(query)
    }

    // MARK: - Save Clinical PhenoAge From Bloodwork OCR
    public func saveClinicalPhenoAge(_ phenoAge: Double) {
        clinicalPhenoAgeValue = (phenoAge * 10).rounded() / 10
        clinicalPhenoAgeDateStr = ISO8601DateFormatter().string(from: Date())
        persistWidgetSnapshot()
        syncEventToMac(extraPayload: ["phenoAge": clinicalPhenoAgeValue, "phenoAgeSource": "iPhone VisionKit Lab OCR"])
    }

    // MARK: - Save Real Workout via Modern HKWorkoutBuilder
    public func logWorkout(
        calories: Double,
        durationMinutes: Double,
        workoutType: HKWorkoutActivityType = .traditionalStrengthTraining
    ) async -> Bool {
        guard isAvailable else { return false }

        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-max(1.0, durationMinutes * 60.0))

        let config = HKWorkoutConfiguration()
        config.activityType = workoutType
        config.locationType = .indoor

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: config, device: .local())

        do {
            try await builder.beginCollection(at: startDate)

            if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                let energyQty = HKQuantity(unit: .kilocalorie(), doubleValue: max(1.0, calories))
                let energySample = HKQuantitySample(type: energyType, quantity: energyQty, start: startDate, end: endDate)
                try await builder.addSamples([energySample])
            }

            if let exType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
                let exQty = HKQuantity(unit: .minute(), doubleValue: max(1.0, durationMinutes))
                let exSample = HKQuantitySample(type: exType, quantity: exQty, start: startDate, end: endDate)
                try await builder.addSamples([exSample])
            }

            try await builder.endCollection(at: endDate)
            _ = try await builder.finishWorkout()

            self.fetchLiveHealthMetrics()
            return true
        } catch {
            ensureDailyCountersAreCurrent()
            offlineMoveKcalToday += calories
            offlineExerciseMinToday += durationMinutes
            self.moveCalories = max(self.moveCalories, self.offlineMoveKcalToday)
            self.exerciseMinutes = max(self.exerciseMinutes, self.offlineExerciseMinToday)
            self.persistWidgetSnapshot()
            self.broadcastToMac()
            return false
        }
    }

    /// Standalone iPhone ingestion hook for parsed Apple Health `export.xml` history.
    public func applyImportedAppleHealthSnapshot(
        hrvPoints: [DailyMetricPoint],
        rhrPoints: [DailyMetricPoint],
        vo2Points: [DailyMetricPoint],
        sleepPoints: [DailyMetricPoint],
        movePoints: [DailyMetricPoint],
        weightPoints: [DailyMetricPoint],
        latestHRV: Double?,
        latestRHR: Double?,
        latestVO2: Double?,
        latestWeightKg: Double?,
        latestBodyFatPct: Double?,
        latestSleepHours: Double?,
        latestDeepHours: Double?,
        latestRemHours: Double?,
        latestCoreHours: Double?,
        latestAwakeHours: Double?,
        latestSpO2: Double?,
        latestRespRate: Double?,
        latestGlucoseMgDl: Double?
    ) {
        if !hrvPoints.isEmpty { hrvHistory = hrvPoints }
        if !rhrPoints.isEmpty { rhrHistory = rhrPoints }
        if !vo2Points.isEmpty { vo2History = vo2Points }
        if !sleepPoints.isEmpty { sleepHistory = sleepPoints }
        if !movePoints.isEmpty { moveHistory = movePoints }
        if !weightPoints.isEmpty { weightHistory = weightPoints }

        if let v = latestHRV { heartRateVariability = v }
        if let v = latestRHR { restingHeartRate = v }
        if let v = latestVO2 { vo2Max = v }
        if let v = latestWeightKg { bodyWeightKg = v }
        if let v = latestBodyFatPct { bodyFatPercent = v }
        if let v = latestSleepHours { sleepTotalHours = v }
        if let v = latestDeepHours { sleepDeepHours = v }
        if let v = latestRemHours { sleepRemHours = v }
        if let v = latestCoreHours { sleepCoreHours = v }
        if let v = latestAwakeHours { sleepAwakeHours = v }
        if let v = latestSpO2 { bloodOxygenPercent = v }
        if let v = latestRespRate { respiratoryRateBpm = v }
        if let g = latestGlucoseMgDl {
            let pt = HourlyMetricPoint(date: Date(), value: g.rounded(), label: "XML Import")
            glucoseSamples24h.append(pt)
            saveManualGlucose(glucoseSamples24h)
        }
        connectionState = .connected
        statusLabel = "Apple Health XML + Live"
        persistWidgetSnapshot()
        broadcastToMac()
    }

    // MARK: - Shared WidgetKit Snapshot Writer
    public func persistWidgetSnapshot() {
        let bestHang = UserDefaults.standard.integer(forKey: "apex_best_deadhang_sec")
        let todayKey = Self.currentDayKey()
        let waterMl = (UserDefaults.standard.string(forKey: "apex_ios_hydration_day_v1") == todayKey)
            ? UserDefaults.standard.double(forKey: "apex_ios_water_today_v1")
            : 0
        let cafMg = (UserDefaults.standard.string(forKey: "apex_ios_hydration_day_v1") == todayKey)
            ? UserDefaults.standard.double(forKey: "apex_ios_caffeine_today_v1")
            : 0
        let sunlightToday = ExperimentLabStore.shared.dailyTagsToday.contains("sunlight")
        let snapshot = ApexWidgetSnapshot(
            moveCalories: moveCalories,
            moveTarget: moveTarget,
            exerciseMinutes: exerciseMinutes,
            exerciseTarget: exerciseTarget,
            standHours: standHours,
            standTarget: standTarget,
            readinessScore: readinessScore,
            energyBank: energyBankPercent,
            strainScore: todayStrainScore,
            hrv: heartRateVariability,
            hrvDeltaPercent: hrvDeltaPercent,
            restingHR: restingHeartRate,
            sleepHours: sleepTotalHours,
            biologicalAge: biologicalAge,
            clinicalPhenoAge: clinicalPhenoAge,
            deadHangBestSec: bestHang,
            dailySteps: dailySteps,
            waterMlToday: waterMl,
            caffeineMgToday: cafMg,
            sunlightLoggedToday: sunlightToday,
            paceOfAging: paceOfAging,
            updatedAt: Date()
        )
        ApexSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Bonjour Auto-Discovery (_apexos._tcp) via Network.framework
    public func startBonjourDiscovery() {
        bonjourBrowser?.cancel()

        let params = NWParameters.tcp
        params.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: "_apexos._tcp", domain: "local."), using: params)

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            var items: [DiscoveredMacEndpoint] = []
            for res in results {
                if case let .service(name, _, _, _) = res.endpoint {
                    var txtToken: String? = nil
                    if case let .bonjour(record) = res.metadata {
                        txtToken = record["token"]
                    }
                    items.append(DiscoveredMacEndpoint(id: name, name: name, host: nil, port: nil, txtToken: txtToken, nwEndpoint: res.endpoint))
                }
            }
            Task { @MainActor in
                self?.discoveredMacs = items
                if let first = items.first, self?.isMacReachable == false {
                    self?.resolveAndConnect(endpoint: first)
                }
            }
        }
        browser.start(queue: DispatchQueue.global(qos: .utility))
        self.bonjourBrowser = browser
    }

    public func resolveAndConnect(endpoint: DiscoveredMacEndpoint) {
        let connection = NWConnection(to: endpoint.nwEndpoint, using: .tcp)
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                if let remote = connection.currentPath?.remoteEndpoint,
                   case let .hostPort(host, port) = remote {
                    let hostStr = Self.cleanHostString(host)
                    let portInt = Int(port.rawValue)
                    Task { @MainActor in
                        guard let self = self else { return }
                        self.macHost = hostStr
                        self.macServerPort = portInt
                        self.macDeviceName = endpoint.name
                        if let txtToken = endpoint.txtToken, !txtToken.isEmpty {
                            self.macSyncToken = txtToken
                        }
                        self.isMacReachable = true
                        if let idx = self.discoveredMacs.firstIndex(where: { $0.id == endpoint.id }) {
                            self.discoveredMacs[idx].host = hostStr
                            self.discoveredMacs[idx].port = portInt
                        }
                        if self.macSyncToken.isEmpty {
                            await self.fetchPairingToken(host: hostStr, port: portInt)
                        }
                        self.broadcastToMac()
                    }
                }
                connection.cancel()
            case .failed, .cancelled:
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: DispatchQueue.global(qos: .utility))
    }

    private func fetchPairingToken(host: String, port: Int) async {
        guard let infoURL = URL(string: "http://\(host):\(port)/api/pairing-info") else { return }
        var req = URLRequest(url: infoURL)
        req.timeoutInterval = 2.0
        guard let (data, response) = try? await URLSession.shared.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["syncToken"] as? String,
              !token.isEmpty else {
            return
        }
        self.macSyncToken = token
    }

    nonisolated private static func cleanHostString(_ host: NWEndpoint.Host) -> String {
        switch host {
        case .ipv4(let addr):
            return "\(addr)".components(separatedBy: "%").first ?? "127.0.0.1"
        case .ipv6(let addr):
            return "\(addr)".components(separatedBy: "%").first ?? "127.0.0.1"
        case .name(let hostname, _):
            return hostname
        @unknown default:
            return "127.0.0.1"
        }
    }

    // MARK: - Unified Continuity Sync to Mac Companion, Watch & Proactive Alerts
    public func broadcastToMac() {
        ApexWatchConnectivity.shared.pushTelemetryToWatch(health: self)
        ApexNotificationsEngine.shared.evaluateHealthMonitorAndSchedule(health: self)
        syncEventToMac(extraPayload: nil)
    }

    public func pushBackupSnapshotToMac(_ jsonData: Data) async -> Bool {
        let cleanHost = macHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanHost.isEmpty,
              let url = URL(string: "http://\(cleanHost):\(macServerPort)/api/backup-sync") else {
            return false
        }
        if macSyncToken.isEmpty {
            await fetchPairingToken(host: cleanHost, port: macServerPort)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !macSyncToken.isEmpty {
            request.setValue(macSyncToken, forHTTPHeaderField: "X-APEX-Sync-Token")
        }
        request.httpBody = jsonData
        request.timeoutInterval = 3.0

        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let httpRes = response as? HTTPURLResponse else {
            return false
        }
        if httpRes.statusCode == 401 {
            await fetchPairingToken(host: cleanHost, port: macServerPort)
            if !macSyncToken.isEmpty {
                request.setValue(macSyncToken, forHTTPHeaderField: "X-APEX-Sync-Token")
                let (_, retryResp) = (try? await URLSession.shared.data(for: request)) ?? (Data(), URLResponse())
                return (retryResp as? HTTPURLResponse)?.statusCode == 200
            }
        }
        return httpRes.statusCode == 200
    }

    public func syncEventToMac(extraPayload: [String: Any]?) {
        guard isSyncingToMac else { return }

        let cleanHost = macHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanHost.isEmpty,
              let url = URL(string: "http://\(cleanHost):\(macServerPort)/api/healthkit-sync") else {
            return
        }

        var payload: [String: Any] = [
            "move": Int(moveCalories),
            "moveGoal": Int(moveTarget),
            "exercise": Int(exerciseMinutes),
            "exerciseGoal": Int(exerciseTarget),
            "stand": Int(standHours),
            "standGoal": Int(standTarget),
            "steps": dailySteps,
            "hr": Int(restingHeartRate ?? 0),
            "hrv": Int(heartRateVariability ?? 0),
            "vo2Max": vo2Max ?? 0,
            "sleepHours": ((sleepTotalHours ?? 0) * 10).rounded() / 10,
            "deepSleepHours": (sleepDeepHours * 10).rounded() / 10,
            "remSleepHours": (sleepRemHours * 10).rounded() / 10,
            "bloodOxygen": bloodOxygenPercent ?? 0,
            "respiratoryRate": respiratoryRateBpm ?? 0,
            "wristTempDelta": wristTempDeltaC ?? 0,
            "bodyFatPercent": bodyFatPercent ?? 0,
            "leanMassKg": leanBodyMassKg ?? 0,
            "readiness": readinessScore ?? 0,
            "strain": todayStrainScore ?? 0,
            "energyBank": energyBankPercent ?? 0,
            "stressScore": currentStressScore ?? 0,
            "sleepNeededHours": sleepNeededHours ?? 0,
            "sleepDebtHours": sleepDebtHours ?? 0,
            "vitalsInRange": vitalRangeSummary.inRange,
            "vitalsTotal": vitalRangeSummary.total,
            "journalTagsToday": ExperimentLabStore.shared.dailyTagsToday,
            "dailyTagsByDate": ExperimentLabStore.shared.dailyTagsByDate,
            "deadHangBest": UserDefaults.standard.integer(forKey: "apex_best_deadhang_sec"),
            "setAbsolute": true,
            "source": "iPhone · Apple HealthKit Live",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        if let latestGlucose = glucoseSamples24h.last?.value {
            payload["glucoseLatest"] = latestGlucose
        }
        if !stressHourlyCurve.isEmpty {
            payload["stressCurve"] = stressHourlyCurve.map { ["label": $0.label, "value": Int($0.value)] }
        }
        if !energyBankCurve.isEmpty {
            payload["energyCurve"] = energyBankCurve.map { ["label": $0.label, "value": Int($0.value)] }
        }

        if let extra = extraPayload {
            for (k, v) in extra {
                payload[k] = v
            }
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else { return }

        let targetHost = cleanHost
        let targetPort = macServerPort
        Task { [weak self] in
            guard let self = self else { return }
            if self.macSyncToken.isEmpty {
                await self.fetchPairingToken(host: targetHost, port: targetPort)
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if !self.macSyncToken.isEmpty {
                request.setValue(self.macSyncToken, forHTTPHeaderField: "X-APEX-Sync-Token")
            }
            request.httpBody = jsonData
            request.timeoutInterval = 2.0

            if let (_, response) = try? await URLSession.shared.data(for: request),
               let httpRes = response as? HTTPURLResponse {
                if httpRes.statusCode == 401 {
                    await self.fetchPairingToken(host: targetHost, port: targetPort)
                    if !self.macSyncToken.isEmpty {
                        request.setValue(self.macSyncToken, forHTTPHeaderField: "X-APEX-Sync-Token")
                        let (_, retryResp) = (try? await URLSession.shared.data(for: request)) ?? (Data(), URLResponse())
                        let ok = (retryResp as? HTTPURLResponse)?.statusCode == 200
                        self.isMacReachable = ok
                        if ok { self.lastSyncTimestamp = Date() }
                        return
                    }
                }
                let ok = httpRes.statusCode == 200
                self.isMacReachable = ok
                if ok {
                    self.lastSyncTimestamp = Date()
                }
            } else {
                self.isMacReachable = false
            }
        }
    }
}
