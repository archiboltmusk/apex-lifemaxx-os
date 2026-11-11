import Foundation
import WatchConnectivity

// MARK: - Bidirectional Apple Watch (watchOS) Session Bridge
@MainActor
public final class ApexWatchConnectivity: NSObject, ObservableObject, WCSessionDelegate {
    public static let shared = ApexWatchConnectivity()

    @Published public var isSupported: Bool = WCSession.isSupported()
    @Published public var isPaired: Bool = false
    @Published public var isWatchAppInstalled: Bool = false
    @Published public var isReachable: Bool = false
    @Published public var lastWatchSetSummary: String? = nil

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    public func pushTelemetryToWatch(health: HealthKitManager) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let nutrition = NutritionLogStore.shared
        var context: [String: Any] = [
            "updatedAt": Date().timeIntervalSince1970,
            "moveCalories": Int(health.moveCalories),
            "moveTarget": Int(health.moveTarget),
            "waterMlToday": Int(nutrition.waterMlToday.rounded()),
            "waterTargetMl": Int(nutrition.waterTargetMl.rounded()),
            "unitSystem": ApexUnitPreferences.current.rawValue
        ]
        if let rdy = health.readinessScore { context["readiness"] = rdy }
        if let bank = health.energyBankPercent { context["energyBank"] = bank }
        if let strain = health.todayStrainScore { context["strain"] = (strain * 10).rounded() / 10 }
        if let range = health.targetStrainRange {
            context["targetLow"] = Int(range.lowerBound.rounded())
            context["targetHigh"] = Int(range.upperBound.rounded())
        }
        if let stress = health.currentStressScore { context["stress"] = stress }
        if let hrv = health.heartRateVariability { context["hrv"] = Int(hrv.rounded()) }
        if let rhr = health.restingHeartRate { context["rhr"] = Int(rhr.rounded()) }
        if let sleepNeed = health.sleepNeededHours { context["sleepNeededHours"] = (sleepNeed * 10).rounded() / 10 }
        if let pace = health.paceOfAging { context["paceOfAging"] = (pace * 100).rounded() / 100 }

        try? session.updateApplicationContext(context)
        if session.isReachable {
            session.sendMessage(context, replyHandler: nil, errorHandler: nil)
        }
    }

    // MARK: - WCSessionDelegate
    nonisolated public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isReachable = session.isReachable
            if activationState == .activated {
                self.pushTelemetryToWatch(health: HealthKitManager.shared)
            }
        }
    }

    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }

    nonisolated public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.handleIncomingWatchPayload(message)
        }
    }

    nonisolated public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            self.handleIncomingWatchPayload(userInfo)
        }
    }

    private func handleIncomingWatchPayload(_ payload: [String: Any]) {
        let health = HealthKitManager.shared
        var shouldPushBack = false

        if let ex = payload["watchExercise"] as? String {
            let weight = payload["weightKg"] as? Double ?? 0
            let reps = payload["reps"] as? Int ?? 8
            let rpe = payload["rpe"] as? Double ?? 8.5
            StrengthBuilderStore.shared.logExternalWatchSet(
                exerciseName: ex,
                weightKg: weight,
                reps: reps,
                rpe: rpe,
                health: health
            )
            lastWatchSetSummary = "\(ex) · \(ApexUnitPreferences.formatWeight(kg: weight)) × \(reps)"
            shouldPushBack = true
        }
        if let hrrDrop = payload["watchHrrDropBpm"] as? Int, hrrDrop > 0 {
            let endBpm = (payload["watchEndBpm"] as? Int) ?? max(40, (payload["watchPeakBpm"] as? Int ?? 120) - hrrDrop)
            let peakBpm = (payload["watchPeakBpm"] as? Int) ?? (endBpm + hrrDrop)
            BLEHeartRateMonitor.appendHRR60Record(
                peakBPM: peakBpm,
                endBPM: endBpm,
                dropBpm: hrrDrop,
                rmssdMs: nil,
                source: "Apple Watch"
            )
            health.syncEventToMac(extraPayload: ["hrr60DropBpm": hrrDrop])
        }
        if let hydrationMl = payload["watchWaterMl"] as? Double, hydrationMl > 0 {
            NutritionLogStore.shared.addWater(ml: hydrationMl, health: health)
            shouldPushBack = true
        }
        if payload["watchRequestRefresh"] as? Bool == true {
            shouldPushBack = true
        }
        if shouldPushBack {
            pushTelemetryToWatch(health: health)
        }
    }
}
