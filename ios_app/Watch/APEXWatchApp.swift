import SwiftUI
import Combine
import HealthKit
import WatchConnectivity
import WatchKit

// MARK: - watchOS Shared Session, Live Workout HR Streamer & Offline Cache
@MainActor
final class WatchBridgeModel: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchBridgeModel()

    private static let cacheKey = "apex_watch_cached_context_v1"

    @Published var readiness: Int? = nil
    @Published var energyBank: Int? = nil
    @Published var strain: Double? = nil
    @Published var targetRangeText: String = "0–21"
    @Published var stressScore: Int? = nil
    @Published var hrvMs: Int? = nil
    @Published var rhrBpm: Int? = nil
    @Published var sleepNeededHours: Double? = nil
    @Published var paceOfAging: Double? = nil
    @Published var waterMlToday: Int = 0
    @Published var waterTargetMl: Int = 3000
    @Published var unitSystemRaw: String = "metric"

    @Published var liveBpm: Int? = nil
    @Published var isWorkoutSessionActive: Bool = false
    @Published var lastStatus: String = "Offline cache ready"

    private let healthStore = HKHealthStore()
    private var hrAnchorQuery: HKAnchoredObjectQuery?
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    private override init() {
        super.init()
        if let cached = UserDefaults.standard.dictionary(forKey: Self.cacheKey) {
            apply(cached, markSynced: false)
        }
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        startHeartRateStreamIfAuthorized()
    }

    var isImperial: Bool {
        unitSystemRaw == "imperial"
    }

    func startHeartRateStreamIfAuthorized() {
        guard HKHealthStore.isHealthDataAvailable(),
              let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        let shareTypes: Set<HKSampleType> = [HKObjectType.workoutType()]
        let readTypes: Set<HKObjectType> = [hrType, HKObjectType.workoutType()]
        healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { [weak self] ok, _ in
            guard ok else { return }
            let start = Date().addingTimeInterval(-3600)
            let pred = HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate)
            let query = HKAnchoredObjectQuery(type: hrType, predicate: pred, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] _, samples, _, _, _ in
                Self.extractAndPublishHR(samples, to: self)
            }
            query.updateHandler = { [weak self] _, samples, _, _, _ in
                Self.extractAndPublishHR(samples, to: self)
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.hrAnchorQuery = query
                self.healthStore.execute(query)
            }
        }
    }

    func toggleLiveWorkoutSession() {
        if isWorkoutSessionActive {
            stopLiveWorkoutSession()
        } else {
            startLiveWorkoutSession()
        }
    }

    func startLiveWorkoutSession() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor
        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            session.delegate = self
            builder.delegate = self
            workoutSession = session
            workoutBuilder = builder
            let start = Date()
            session.startActivity(with: start)
            builder.beginCollection(withStart: start) { _, _ in }
            isWorkoutSessionActive = true
            WKInterfaceDevice.current().play(.start)
            lastStatus = "Live optical HR active"
        } catch {
            lastStatus = "Background HR active"
            isWorkoutSessionActive = false
        }
    }

    func stopLiveWorkoutSession() {
        WKInterfaceDevice.current().play(.stop)
        let end = Date()
        let activeSession = workoutSession
        let activeBuilder = workoutBuilder
        workoutSession = nil
        workoutBuilder = nil
        isWorkoutSessionActive = false
        lastStatus = "Session ended"
        activeSession?.end()
        activeBuilder?.endCollection(withEnd: end) { _, _ in
            activeBuilder?.finishWorkout { _, _ in }
        }
    }

    nonisolated private static func extractAndPublishHR(_ samples: [HKSample]?, to model: WatchBridgeModel?) {
        guard let qty = (samples?.last as? HKQuantitySample)?.quantity else { return }
        let bpm = Int(qty.doubleValue(for: HKUnit.count().unitDivided(by: .minute())).rounded())
        Task { @MainActor in
            model?.liveBpm = bpm
        }
    }

    func sendSetToPhone(exercise: String, weightKg: Double, reps: Int, rpe: Double) {
        WKInterfaceDevice.current().play(.success)
        let msg: [String: Any] = [
            "watchExercise": exercise,
            "weightKg": weightKg,
            "reps": reps,
            "rpe": rpe
        ]
        sendPayload(msg)
        lastStatus = "Logged \(exercise) (\(reps)r)"
    }

    func sendWaterToPhone(ml: Double = 250) {
        WKInterfaceDevice.current().play(.click)
        waterMlToday += Int(ml.rounded())
        let msg: [String: Any] = ["watchWaterMl": ml]
        sendPayload(msg)
        lastStatus = "+\(Int(ml)) mL water sent"
    }

    func sendHRR60ToPhone(peakBpm: Int, endBpm: Int, dropBpm: Int) {
        WKInterfaceDevice.current().play(.notification)
        let msg: [String: Any] = [
            "watchHrrDropBpm": dropBpm,
            "watchPeakBpm": peakBpm,
            "watchEndBpm": endBpm
        ]
        sendPayload(msg)
        lastStatus = "HRR-60 -\(dropBpm) bpm"
    }

    func requestSyncFromPhone() {
        WKInterfaceDevice.current().play(.click)
        sendPayload(["watchRequestRefresh": true])
        lastStatus = "Syncing iPhone..."
    }

    private func sendPayload(_ msg: [String: Any]) {
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(msg, replyHandler: nil, errorHandler: nil)
        } else {
            WCSession.default.transferUserInfo(msg)
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated {
            let received = session.receivedApplicationContext
            if !received.isEmpty {
                Task { @MainActor in self.apply(received, markSynced: true) }
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.apply(applicationContext, markSynced: true) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.apply(message, markSynced: true) }
    }

    private func apply(_ dict: [String: Any], markSynced: Bool) {
        if let r = dict["readiness"] as? Int { readiness = r }
        if let b = dict["energyBank"] as? Int { energyBank = b }
        if let s = dict["strain"] as? Double { strain = s }
        if let low = dict["targetLow"] as? Int, let high = dict["targetHigh"] as? Int {
            targetRangeText = "\(low)–\(high)"
        }
        if let st = dict["stress"] as? Int { stressScore = st }
        if let h = dict["hrv"] as? Int { hrvMs = h }
        if let rh = dict["rhr"] as? Int { rhrBpm = rh }
        if let sn = dict["sleepNeededHours"] as? Double { sleepNeededHours = sn }
        if let pa = dict["paceOfAging"] as? Double { paceOfAging = pa }
        if let w = dict["waterMlToday"] as? Int { waterMlToday = w }
        if let wt = dict["waterTargetMl"] as? Int, wt > 0 { waterTargetMl = wt }
        if let u = dict["unitSystem"] as? String { unitSystemRaw = u }

        if markSynced {
            lastStatus = "Synced with iPhone"
            // Store clean scalar subset for instant offline cold launch
            let serializable = dict.filter { _, val in
                val is Int || val is Double || val is String || val is Bool
            }
            UserDefaults.standard.set(serializable, forKey: Self.cacheKey)
        }
    }
}

extension WatchBridgeModel: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {}
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate),
              collectedTypes.contains(hrType),
              let stats = workoutBuilder.statistics(for: hrType),
              let qty = stats.mostRecentQuantity() else { return }
        let bpm = Int(qty.doubleValue(for: HKUnit.count().unitDivided(by: .minute())).rounded())
        Task { @MainActor in
            self.liveBpm = bpm
        }
    }
}

struct WatchBevelRecoveryView: View {
    @ObservedObject var model: WatchBridgeModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("APEX")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color(red: 0.90, green: 0.99, blue: 0.25))
                    Spacer()
                    Button {
                        model.requestSyncFromPhone()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.cyan)
                    }
                    .buttonStyle(.plain)
                }

                HStack {
                    metricBox(title: "RDY", value: model.readiness.map { "\($0)%" } ?? "—", color: .green)
                    metricBox(title: "BANK", value: model.energyBank.map { "\($0)%" } ?? "—", color: .cyan)
                }

                HStack {
                    metricBox(title: "STRAIN", value: model.strain.map { String(format: "%.1f", $0) } ?? "—", color: .orange)
                    metricBox(title: "GOAL", value: model.targetRangeText, color: .white)
                }

                HStack {
                    metricBox(title: "HRV", value: model.hrvMs.map { "\($0)ms" } ?? "—", color: .mint)
                    metricBox(title: "RHR", value: model.rhrBpm.map { "\($0)" } ?? "—", color: .red)
                }

                HStack {
                    metricBox(title: "STRESS", value: model.stressScore.map { "\($0)" } ?? "—", color: .yellow)
                    metricBox(title: "SLEEP NEED", value: model.sleepNeededHours.map { String(format: "%.1fh", $0) } ?? "—", color: .indigo)
                }

                Button {
                    model.sendWaterToPhone(ml: 250)
                } label: {
                    HStack {
                        Image(systemName: "drop.fill")
                        Text("+250 mL (\(model.waterMlToday)/\(model.waterTargetMl))")
                            .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    }
                    .frame(maxWidth: .infinity)
                }
                .tint(.cyan)

                Text(model.lastStatus)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }

    private func metricBox(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(7)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct WatchSetLoggerView: View {
    @ObservedObject var model: WatchBridgeModel
    private let exercises = [
        "Back Squat", "Bench Press", "Deadlift", "Overhead Press", "Pull-Ups",
        "RDL", "Barbell Row", "Split Squat", "Incline DB Press", "Weighted Dips"
    ]
    @State private var selectedIdx = 0
    @State private var weightKg: Double = 60
    @State private var reps: Int = 8
    @State private var rpe: Double = 8.5
    @State private var restSeconds: Int = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Picker("Lift", selection: $selectedIdx) {
                    ForEach(0..<exercises.count, id: \.self) { i in
                        Text(exercises[i]).tag(i)
                    }
                }
                .labelsHidden()
                .frame(height: 38)

                let stepKg = model.isImperial ? (5.0 / 2.20462) : 2.5
                let displayWeight = model.isImperial ? Int((weightKg * 2.20462).rounded()) : Int(weightKg.rounded())
                let unitStr = model.isImperial ? "lbs" : "kg"

                HStack(spacing: 6) {
                    Button("-") { weightKg = max(0, weightKg - stepKg) }
                    Text("\(displayWeight) \(unitStr)")
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                    Button("+") { weightKg += stepKg }
                }

                HStack(spacing: 6) {
                    Button("-") { reps = max(1, reps - 1) }
                    Text("\(reps) reps")
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                    Button("+") { reps += 1 }
                }

                HStack(spacing: 6) {
                    Button("-") { rpe = max(6.0, rpe - 0.5) }
                    Text(String(format: "RPE %.1f", rpe))
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.orange)
                    Button("+") { rpe = min(10.0, rpe + 0.5) }
                }

                Button("Log Set") {
                    model.sendSetToPhone(
                        exercise: exercises[selectedIdx],
                        weightKg: (weightKg * 10).rounded() / 10,
                        reps: reps,
                        rpe: rpe
                    )
                    restSeconds = 90
                }
                .tint(Color(red: 0.90, green: 0.99, blue: 0.25))

                if restSeconds > 0 {
                    Text("Rest: \(restSeconds)s")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.cyan)
                }
            }
            .padding(.horizontal, 4)
        }
        .onReceive(timer) { _ in
            if restSeconds > 0 {
                restSeconds -= 1
                if restSeconds == 0 {
                    WKInterfaceDevice.current().play(.notification)
                }
            }
        }
    }
}

struct WatchHeartRateView: View {
    @ObservedObject var model: WatchBridgeModel
    @State private var peakBpm: Int? = nil
    @State private var countdown: Int = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text(model.liveBpm.map { "\($0) BPM" } ?? "— BPM")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.red)

                Button(model.isWorkoutSessionActive ? "Stop Live Workout HR" : "Start Live Workout HR") {
                    model.toggleLiveWorkoutSession()
                }
                .tint(model.isWorkoutSessionActive ? .red : .green)

                if countdown > 0 {
                    Text("HRR-60: \(countdown)s")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.cyan)
                } else {
                    Button("Start HRR-60") {
                        if let bpm = model.liveBpm {
                            peakBpm = bpm
                            countdown = 60
                        }
                    }
                    .disabled(model.liveBpm == nil)
                }

                if model.liveBpm == nil {
                    Text("Start Live Workout HR or allow Health HR permission for HRR-60.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 4)
        }
        .onReceive(timer) { _ in
            if countdown > 0 {
                countdown -= 1
                if countdown == 0, let peak = peakBpm, let now = model.liveBpm {
                    model.sendHRR60ToPhone(
                        peakBpm: peak,
                        endBpm: now,
                        dropBpm: max(0, peak - now)
                    )
                }
            }
        }
    }
}

@main
struct APEXWatchApp: App {
    @StateObject private var model = WatchBridgeModel.shared

    var body: some Scene {
        WindowGroup {
            TabView {
                WatchBevelRecoveryView(model: model)
                WatchSetLoggerView(model: model)
                WatchHeartRateView(model: model)
            }
            .tabViewStyle(.page)
        }
    }
}
