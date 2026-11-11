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

    // Overnight Recovery Sensors
    @Published public var bloodOxygenPercent: Double? = nil
    @Published public var respiratoryRateBpm: Double? = nil
    @Published public var wristTempDeltaC: Double? = nil
    @Published public var bodyWeightKg: Double? = nil

    // 7-Day Personal Rolling History & Baselines
    @Published public var hrvHistory: [DailyMetricPoint] = []
    @Published public var rhrHistory: [DailyMetricPoint] = []
    @Published public var vo2History: [DailyMetricPoint] = []
    @Published public var sleepHistory: [DailyMetricPoint] = []
    @Published public var moveHistory: [DailyMetricPoint] = []

    // Biological & Clinical Epigenetic Age
    @AppStorage("apex_chronological_age") public var chronologicalAge: Double = 26.0
    @AppStorage("apex_age_manually_set") public var isAgeManuallySet: Bool = false
    @AppStorage("apex_mac_token") public var macSyncToken: String = ""
    @AppStorage("apex_clinical_phenoage") public var clinicalPhenoAgeValue: Double = 0
    @AppStorage("apex_clinical_phenoage_updated") public var clinicalPhenoAgeDateStr: String = ""

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

    private init() {
        self.isAvailable = HKHealthStore.isHealthDataAvailable()
        if isAvailable {
            self.connectionState = .needsPermission
            self.statusLabel = "Connect Apple Health"
        } else {
            self.connectionState = .unavailable
            self.statusLabel = "Health Data Unavailable"
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
            .bodyMass
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

        var shareTypes = Set<HKSampleType>()
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            shareTypes.insert(energy)
        }
        if let exTime = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) {
            shareTypes.insert(exTime)
        }
        if let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) {
            shareTypes.insert(hrType)
        }
        if let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            shareTypes.insert(hrvType)
        }
        shareTypes.insert(HKObjectType.workoutType())

        connectionState = .connecting
        statusLabel = "Connecting..."

        healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { [weak self] success, _ in
            Task { @MainActor in
                guard let self = self else { return }
                if success {
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

                    self.moveCalories = move
                    self.moveTarget = moveGoal
                    self.exerciseMinutes = ex
                    self.exerciseTarget = exGoal
                    self.standHours = stand
                    self.standTarget = standGoal
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

        // 3. 14-Day Resting HR Samples & Latest (supports 7d baseline + 14d N-of-1 trials)
        fetchRecentSamples(
            identifier: .restingHeartRate,
            unit: HKUnit(from: "count/min"),
            daysBack: 14
        ) { [weak self] points in
            guard let self = self else { return }
            self.rhrHistory = points
            self.restingHeartRate = points.last?.value
            self.persistWidgetSnapshot()
            self.broadcastToMac()
        }

        // 4. 14-Day HRV (SDNN) Samples & Latest (supports 7d baseline + 14d N-of-1 trials)
        fetchRecentSamples(
            identifier: .heartRateVariabilitySDNN,
            unit: .secondUnit(with: .milli),
            daysBack: 14
        ) { [weak self] points in
            guard let self = self else { return }
            self.hrvHistory = points
            self.heartRateVariability = points.last?.value
            self.persistWidgetSnapshot()
            self.broadcastToMac()
        }

        // 5. 7-Day / Latest VO2 Max
        fetchRecentSamples(identifier: .vo2Max, unit: HKUnit(from: "ml/kg*min"), daysBack: 30) { [weak self] points in
            guard let self = self else { return }
            self.vo2History = Array(points.suffix(7))
            self.vo2Max = points.last?.value
            self.persistWidgetSnapshot()
        }

        // 6. Overnight Oxygen Saturation, Respiratory Rate & Wrist Temp
        fetchLatestQuantity(identifier: .oxygenSaturation, unit: .percent()) { [weak self] val in
            self?.bloodOxygenPercent = val.map { min(100.0, ($0 * 100.0).rounded()) }
        }
        fetchLatestQuantity(identifier: .respiratoryRate, unit: HKUnit(from: "count/min")) { [weak self] val in
            self?.respiratoryRateBpm = val.map { ($0 * 10).rounded() / 10 }
        }
        fetchLatestQuantity(identifier: .bodyMass, unit: .gramUnit(with: .kilo)) { [weak self] val in
            self?.bodyWeightKg = val
        }
        if #available(iOS 16.0, *) {
            fetchLatestQuantity(identifier: .appleSleepingWristTemperature, unit: .degreeCelsius()) { [weak self] val in
                self?.wristTempDeltaC = val.map { ($0 * 100).rounded() / 100 }
            }
        }

        // 7. 7-Day Active Energy Collection for Trend Charts
        fetch7DayCumulativeCollection(identifier: .activeEnergyBurned, unit: .kilocalorie()) { [weak self] points in
            self?.moveHistory = points
        }

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
                    self?.moveCalories = kcal
                    self?.persistWidgetSnapshot()
                    self?.broadcastToMac()
                }
            }
            healthStore.execute(query)
        }
        if let exType = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) {
            let query = HKStatisticsQuery(quantityType: exType, quantitySamplePredicate: todayPredicate, options: .cumulativeSum) { [weak self] _, stats, _ in
                let mins = stats?.sumQuantity()?.doubleValue(for: .minute()) ?? 0
                Task { @MainActor in
                    self?.exerciseMinutes = mins
                    self?.persistWidgetSnapshot()
                }
            }
            healthStore.execute(query)
        }
        if let standType = HKObjectType.quantityType(forIdentifier: .appleStandTime) {
            let query = HKStatisticsQuery(quantityType: standType, quantitySamplePredicate: todayPredicate, options: .cumulativeSum) { [weak self] _, stats, _ in
                let mins = stats?.sumQuantity()?.doubleValue(for: .minute()) ?? 0
                Task { @MainActor in
                    self?.standHours = floor(mins / 5.0)
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
            self.moveCalories += calories
            self.exerciseMinutes += durationMinutes
            self.persistWidgetSnapshot()
            self.broadcastToMac()
            return false
        }
    }

    // MARK: - Shared WidgetKit Snapshot Writer
    public func persistWidgetSnapshot() {
        let bestHang = UserDefaults.standard.integer(forKey: "apex_best_deadhang_sec")
        let snapshot = ApexWidgetSnapshot(
            moveCalories: moveCalories,
            moveTarget: moveTarget,
            exerciseMinutes: exerciseMinutes,
            exerciseTarget: exerciseTarget,
            standHours: standHours,
            standTarget: standTarget,
            readinessScore: readinessScore,
            hrv: heartRateVariability,
            hrvDeltaPercent: hrvDeltaPercent,
            restingHR: restingHeartRate,
            sleepHours: sleepTotalHours,
            biologicalAge: biologicalAge,
            clinicalPhenoAge: clinicalPhenoAge,
            deadHangBestSec: bestHang,
            dailySteps: dailySteps,
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

    // MARK: - Unified Continuity Sync to Mac Companion
    public func broadcastToMac() {
        syncEventToMac(extraPayload: nil)
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
            "readiness": readinessScore ?? 0,
            "deadHangBest": UserDefaults.standard.integer(forKey: "apex_best_deadhang_sec"),
            "setAbsolute": true,
            "source": "iPhone · Apple HealthKit Live",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

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
