import Foundation
import HealthKit
import Combine
import SwiftUI

public enum HealthConnectionState: Equatable {
    case needsPermission
    case connecting
    case connected
    case unavailable
}

// MARK: - Native Apple HealthKit Telemetry Engine
@MainActor
public class HealthKitManager: ObservableObject {
    public static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()

    // Clean Connection State (Never leaks raw developer errors)
    @Published public var isAvailable: Bool = false
    @Published public var connectionState: HealthConnectionState = .needsPermission
    @Published public var statusLabel: String = "Apple Health Ready"

    // Concentric Activity Rings Data (Real-Time Today)
    @Published public var moveCalories: Double = 0
    @Published public var moveTarget: Double = 750
    @Published public var exerciseMinutes: Double = 0
    @Published public var exerciseTarget: Double = 30
    @Published public var standHours: Double = 0
    @Published public var standTarget: Double = 12

    // Measured Vitals & Longevity
    @Published public var restingHeartRate: Double? = nil
    @Published public var heartRateVariability: Double? = nil
    @Published public var vo2Max: Double? = nil
    @Published public var sleepTotalHours: Double? = nil
    @Published public var dailySteps: Int = 0

    // Biological Age Inputs
    @AppStorage("apex_chronological_age") public var chronologicalAge: Double = 26.0

    // Mac Companion Sync Settings
    @AppStorage("apex_mac_host") public var macHost: String = "127.0.0.1"
    @AppStorage("apex_mac_port") public var macServerPort: Int = 60159
    @AppStorage("apex_sync_enabled") public var isSyncingToMac: Bool = true
    @Published public var isMacReachable: Bool = false
    @Published public var lastSyncTimestamp: Date? = nil

    private var observerQueries: [HKObserverQuery] = []

    public var isAuthorized: Bool {
        connectionState == .connected
    }

    // Derived Autonomic Readiness (0–100) from real vitals when available
    public var readinessScore: Int? {
        guard restingHeartRate != nil || heartRateVariability != nil || sleepTotalHours != nil else {
            return nil
        }
        var score = 78.0
        if let hrv = heartRateVariability {
            score += min(15.0, max(-15.0, (hrv - 55.0) * 0.35))
        }
        if let rhr = restingHeartRate {
            score += min(10.0, max(-12.0, (62.0 - rhr) * 0.5))
        }
        if let sleep = sleepTotalHours {
            if sleep >= 7.5 { score += 5.0 }
            else if sleep < 6.0 { score -= 10.0 }
        }
        return Int(max(20, min(99, score.rounded())))
    }

    // Derived Biological Fitness Age (Livity / Levine composite)
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
    }

    // MARK: - Request Apple Health Permission
    public func requestAuthorization() {
        guard isAvailable else {
            connectionState = .unavailable
            statusLabel = "Health Data Unavailable"
            return
        }

        var readTypes = Set<HKObjectType>()
        let quantityIds: [HKQuantityTypeIdentifier] = [
            .activeEnergyBurned,
            .appleExerciseTime,
            .appleStandTime,
            .stepCount,
            .heartRate,
            .restingHeartRate,
            .heartRateVariabilitySDNN,
            .vo2Max
        ]
        for id in quantityIds {
            if let q = HKObjectType.quantityType(forIdentifier: id) {
                readTypes.insert(q)
            }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(sleep)
        }

        var shareTypes = Set<HKSampleType>()
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            shareTypes.insert(energy)
        }
        if let exTime = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) {
            shareTypes.insert(exTime)
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
            .heartRate
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

    // MARK: - Fetch Real Today's Biometrics from HealthKit
    public func fetchLiveHealthMetrics() {
        guard isAvailable else { return }

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let todayPredicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        // 1. Move Calories
        if let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: todayPredicate, options: .cumulativeSum) { [weak self] _, stats, _ in
                let kcal = stats?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                Task { @MainActor in
                    self?.moveCalories = kcal
                    self?.broadcastToMac()
                }
            }
            healthStore.execute(query)
        }

        // 2. Exercise Minutes
        if let exType = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) {
            let query = HKStatisticsQuery(quantityType: exType, quantitySamplePredicate: todayPredicate, options: .cumulativeSum) { [weak self] _, stats, _ in
                let mins = stats?.sumQuantity()?.doubleValue(for: .minute()) ?? 0
                Task { @MainActor in
                    self?.exerciseMinutes = mins
                }
            }
            healthStore.execute(query)
        }

        // 3. Stand Time (Convert minutes to active hours bracket cleanly)
        if let standType = HKObjectType.quantityType(forIdentifier: .appleStandTime) {
            let query = HKStatisticsQuery(quantityType: standType, quantitySamplePredicate: todayPredicate, options: .cumulativeSum) { [weak self] _, stats, _ in
                let mins = stats?.sumQuantity()?.doubleValue(for: .minute()) ?? 0
                Task { @MainActor in
                    self?.standHours = floor(mins / 5.0) // Stand credit proxy when standalone stand hours aren't queried
                }
            }
            healthStore.execute(query)
        }

        // 4. Daily Steps
        if let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) {
            let query = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: todayPredicate, options: .cumulativeSum) { [weak self] _, stats, _ in
                let count = Int(stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                Task { @MainActor in
                    self?.dailySteps = count
                }
            }
            healthStore.execute(query)
        }

        // 5. Latest Resting Heart Rate
        if let rhrType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: rhrType, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                if let sample = samples?.first as? HKQuantitySample {
                    let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    Task { @MainActor in
                        self?.restingHeartRate = bpm
                    }
                }
            }
            healthStore.execute(query)
        }

        // 6. Latest HRV (SDNN)
        if let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: hrvType, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                if let sample = samples?.first as? HKQuantitySample {
                    let ms = sample.quantity.doubleValue(for: .secondUnit(with: .milli))
                    Task { @MainActor in
                        self?.heartRateVariability = ms
                    }
                }
            }
            healthStore.execute(query)
        }

        // 7. Latest VO2 Max
        if let vo2Type = HKObjectType.quantityType(forIdentifier: .vo2Max) {
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: vo2Type, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                if let sample = samples?.first as? HKQuantitySample {
                    let mlKgMin = sample.quantity.doubleValue(for: HKUnit(from: "ml/kg*min"))
                    Task { @MainActor in
                        self?.vo2Max = mlKgMin
                    }
                }
            }
            healthStore.execute(query)
        }

        // 8. Last Night's Sleep Analysis
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            let yesterday = calendar.date(byAdding: .hour, value: -24, to: now) ?? startOfDay
            let sleepPred = HKQuery.predicateForSamples(withStart: yesterday, end: now, options: .strictStartDate)
            let query = HKSampleQuery(sampleType: sleepType, predicate: sleepPred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, _ in
                guard let categorySamples = samples as? [HKCategorySample] else { return }
                var totalSeconds: TimeInterval = 0
                for s in categorySamples {
                    if s.value != HKCategoryValueSleepAnalysis.inBed.rawValue && s.value != HKCategoryValueSleepAnalysis.awake.rawValue {
                        totalSeconds += s.endDate.timeIntervalSince(s.startDate)
                    }
                }
                if totalSeconds > 0 {
                    Task { @MainActor in
                        self?.sleepTotalHours = totalSeconds / 3600.0
                    }
                }
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Save Real Workout via Modern HKWorkoutBuilder (Zero Deprecations)
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
            // Update local telemetry gracefully even if Health write permission is declined
            self.moveCalories += calories
            self.exerciseMinutes += durationMinutes
            self.broadcastToMac()
            return false
        }
    }

    // MARK: - Sync Biometrics to APEX Mac Desktop App
    public func broadcastToMac() {
        guard isSyncingToMac else { return }

        let cleanHost = macHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanHost.isEmpty,
              let url = URL(string: "http://\(cleanHost):\(macServerPort)/api/healthkit-sync") else {
            return
        }

        let payload: [String: Any] = [
            "move": Int(moveCalories),
            "exercise": Int(exerciseMinutes),
            "stand": Int(standHours),
            "steps": dailySteps,
            "hr": Int(restingHeartRate ?? 0),
            "hrv": Int(heartRateVariability ?? 0),
            "vo2Max": vo2Max ?? 0,
            "source": "iPhone · Apple HealthKit Live",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 1.5

        let task = URLSession.shared.dataTask(with: request) { [weak self] _, response, _ in
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            Task { @MainActor in
                self?.isMacReachable = ok
                if ok {
                    self?.lastSyncTimestamp = Date()
                }
            }
        }
        task.resume()
    }
}
