import SwiftUI
import Combine
import HealthKit
import WatchConnectivity
import WatchKit

// MARK: - watchOS Shared Session & HealthKit HR Streamer
@MainActor
final class WatchBridgeModel: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchBridgeModel()

    @Published var readiness: Int? = nil
    @Published var energyBank: Int? = nil
    @Published var strain: Double? = nil
    @Published var targetRangeText: String = "0–21"
    @Published var liveBpm: Int? = nil
    @Published var lastStatus: String = "Pair with iPhone APEX"

    private let healthStore = HKHealthStore()
    private var hrAnchorQuery: HKAnchoredObjectQuery?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        startHeartRateStreamIfAuthorized()
    }

    func startHeartRateStreamIfAuthorized() {
        guard HKHealthStore.isHealthDataAvailable(),
              let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        healthStore.requestAuthorization(toShare: [], read: [hrType]) { [weak self] ok, _ in
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
                guard let self = self else { return }
                self.hrAnchorQuery = query
                self.healthStore.execute(query)
            }
        }
    }

    nonisolated private static func extractAndPublishHR(_ samples: [HKSample]?, to model: WatchBridgeModel?) {
        guard let qty = (samples?.last as? HKQuantitySample)?.quantity else { return }
        let bpm = Int(qty.doubleValue(for: HKUnit.count().unitDivided(by: .minute())).rounded())
        Task { @MainActor in
            model?.liveBpm = bpm
        }
    }

    func sendSetToPhone(exercise: String, weightKg: Double, reps: Int) {
        WKInterfaceDevice.current().play(.success)
        let msg: [String: Any] = [
            "watchExercise": exercise,
            "weightKg": weightKg,
            "reps": reps,
            "rpe": 8.5
        ]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(msg, replyHandler: nil, errorHandler: nil)
        } else {
            WCSession.default.transferUserInfo(msg)
        }
        lastStatus = "Sent \(exercise) (\(reps)r)"
    }

    func sendHRR60ToPhone(dropBpm: Int) {
        WKInterfaceDevice.current().play(.notification)
        let msg: [String: Any] = ["watchHrrDropBpm": dropBpm]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(msg, replyHandler: nil, errorHandler: nil)
        } else {
            WCSession.default.transferUserInfo(msg)
        }
        lastStatus = "HRR-60 -\(dropBpm) bpm"
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.apply(applicationContext) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.apply(message) }
    }

    private func apply(_ dict: [String: Any]) {
        if let r = dict["readiness"] as? Int { readiness = r }
        if let b = dict["energyBank"] as? Int { energyBank = b }
        if let s = dict["strain"] as? Double { strain = s }
        if let low = dict["targetLow"] as? Int, let high = dict["targetHigh"] as? Int {
            targetRangeText = "\(low)–\(high)"
        }
        lastStatus = "Synced with iPhone"
    }
}

struct WatchBevelRecoveryView: View {
    @ObservedObject var model: WatchBridgeModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("APEX")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color(red: 0.90, green: 0.99, blue: 0.25))

                HStack {
                    metricBox(title: "RDY", value: model.readiness.map { "\($0)%" } ?? "—", color: .green)
                    metricBox(title: "BANK", value: model.energyBank.map { "\($0)%" } ?? "—", color: .cyan)
                }

                HStack {
                    metricBox(title: "STRAIN", value: model.strain.map { String(format: "%.1f", $0) } ?? "—", color: .orange)
                    metricBox(title: "GOAL", value: model.targetRangeText, color: .white)
                }

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
                .font(.system(size: 16, weight: .bold, design: .rounded))
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
    private let exercises = ["Back Squat", "Bench Press", "Pull-Ups", "RDL", "OHP"]
    @State private var selectedIdx = 0
    @State private var weightKg: Double = 60
    @State private var reps: Int = 8
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
                .frame(height: 36)

                HStack(spacing: 6) {
                    Button("-") { weightKg = max(0, weightKg - 2.5) }
                    Text("\(Int(weightKg)) kg")
                        .font(.system(size: 14, weight: .bold).monospacedDigit())
                    Button("+") { weightKg += 2.5 }
                }

                HStack(spacing: 6) {
                    Button("-") { reps = max(1, reps - 1) }
                    Text("\(reps) reps")
                        .font(.system(size: 14, weight: .bold).monospacedDigit())
                    Button("+") { reps += 1 }
                }

                Button("Log Set") {
                    model.sendSetToPhone(exercise: exercises[selectedIdx], weightKg: weightKg, reps: reps)
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
        VStack(spacing: 10) {
            Text(model.liveBpm.map { "\($0) BPM" } ?? "— BPM")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.red)

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
                Text("Allow Health HR permission to run HRR-60 recovery.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .onReceive(timer) { _ in
            if countdown > 0 {
                countdown -= 1
                if countdown == 0, let peak = peakBpm, let now = model.liveBpm {
                    model.sendHRR60ToPhone(dropBpm: max(0, peak - now))
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
