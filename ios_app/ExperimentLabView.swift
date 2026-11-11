import SwiftUI
import Combine

// MARK: - 14-Day N-of-1 Causal Experiment Protocol Models
public struct ExperimentProtocol: Identifiable, Codable, Hashable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let hypothesis: String
    public let icon: String
    public let accentHex: String

    public static let presets: [ExperimentProtocol] = [
        ExperimentProtocol(
            id: "no_caffeine_12pm",
            title: "No Caffeine After 12 PM",
            subtitle: "Adenosine clearance & deep sleep",
            hypothesis: "Measures paired next-morning HRV & RHR on compliant vs non-compliant days.",
            icon: "cup.and.saucer.fill",
            accentHex: "#FF9F0A"
        ),
        ExperimentProtocol(
            id: "nasal_tape",
            title: "Evening Nasal Breathing",
            subtitle: "CO2 tolerance & nocturnal pulse",
            hypothesis: "Tracks overnight RHR & sleep duration deltas across compliant nights.",
            icon: "wind",
            accentHex: "#0A84FF"
        ),
        ExperimentProtocol(
            id: "zone2_40m",
            title: "Zone 2 Aerobic 40m",
            subtitle: "Mitochondrial & vagal tone",
            hypothesis: "Compares resting heart rate & HRV 24h after steady aerobic output.",
            icon: "heart.circle.fill",
            accentHex: "#30D158"
        ),
        ExperimentProtocol(
            id: "early_dinner",
            title: "Finish Dinner 3h Pre-Bed",
            subtitle: "Parasympathetic overnight drop",
            hypothesis: "Tests whether earlier digestion lowers sleeping RHR and raises HRV.",
            icon: "fork.knife",
            accentHex: "#BF5AF2"
        ),
        ExperimentProtocol(
            id: "creatine_electrolytes",
            title: "Morning Electrolytes + 5g Creatine",
            subtitle: "Plasma volume & neural drive",
            hypothesis: "Audits readiness, HRV, and daytime cognitive output against baseline.",
            icon: "drop.fill",
            accentHex: "#64D2FF"
        )
    ]
}

public struct ExperimentLogEntry: Codable, Hashable {
    public let dateKey: String
    public let protocolId: String
    public let adhered: Bool
}

public struct ExperimentCorrelationSummary {
    public let onDaysCount: Int
    public let offDaysCount: Int
    public let hrvDeltaPct: Double?
    public let rhrDeltaBpm: Double?
    public let sleepDeltaMin: Double?
    public let verdict: String
}

// MARK: - Store
@MainActor
public final class ExperimentLabStore: ObservableObject {
    public static let shared = ExperimentLabStore()

    @Published public var activeProtocolId: String {
        didSet { UserDefaults.standard.set(activeProtocolId, forKey: "apex_active_experiment_id") }
    }
    @Published public private(set) var logs: [ExperimentLogEntry] = []

    private let logsKey = "apex_experiment_logs_v1"

    private init() {
        self.activeProtocolId = UserDefaults.standard.string(forKey: "apex_active_experiment_id") ?? ExperimentProtocol.presets[0].id
        if let data = UserDefaults.standard.data(forKey: logsKey),
           let decoded = try? JSONDecoder().decode([ExperimentLogEntry].self, from: data) {
            self.logs = decoded
        }
    }

    public var activeProtocol: ExperimentProtocol {
        ExperimentProtocol.presets.first(where: { $0.id == activeProtocolId }) ?? ExperimentProtocol.presets[0]
    }

    public func todayKey() -> String {
        Self.dayKey(for: Date())
    }

    public func logToday(adhered: Bool) {
        let key = todayKey()
        logs.removeAll { $0.dateKey == key && $0.protocolId == activeProtocolId }
        logs.append(ExperimentLogEntry(dateKey: key, protocolId: activeProtocolId, adhered: adhered))
        persist()
        Haptics.success()

        let summary = correlation(for: activeProtocolId, health: HealthKitManager.shared)
        HealthKitManager.shared.syncEventToMac(extraPayload: [
            "experimentProtocol": activeProtocol.title,
            "experimentAdheredToday": adhered,
            "experimentOnDays": summary.onDaysCount,
            "experimentHrvDeltaPct": summary.hrvDeltaPct ?? 0,
            "experimentRhrDeltaBpm": summary.rhrDeltaBpm ?? 0
        ])
    }

    public func todayStatus(for protocolId: String) -> Bool? {
        let key = todayKey()
        return logs.first(where: { $0.dateKey == key && $0.protocolId == protocolId })?.adhered
    }

    public func correlation(for protocolId: String, health: HealthKitManager) -> ExperimentCorrelationSummary {
        let relevantLogs = logs.filter { $0.protocolId == protocolId }
        let onKeys = Set(relevantLogs.filter { $0.adhered }.map { $0.dateKey })
        let offKeys = Set(relevantLogs.filter { !$0.adhered }.map { $0.dateKey })

        let hrvByDay = Dictionary(uniqueKeysWithValues: health.hrvHistory.map { (Self.dayKey(for: $0.date), $0.value) })
        let rhrByDay = Dictionary(uniqueKeysWithValues: health.rhrHistory.map { (Self.dayKey(for: $0.date), $0.value) })
        let sleepByDay = Dictionary(uniqueKeysWithValues: health.sleepHistory.map { (Self.dayKey(for: $0.date), $0.value) })

        let onHRV = onKeys.compactMap { hrvByDay[$0] }
        let offHRV = offKeys.isEmpty ? health.hrvHistory.filter { !onKeys.contains(Self.dayKey(for: $0.date)) }.map(\.value) : offKeys.compactMap { hrvByDay[$0] }

        let hrvDeltaPct: Double? = {
            guard !onHRV.isEmpty, !offHRV.isEmpty else { return nil }
            let mOn = onHRV.reduce(0, +) / Double(onHRV.count)
            let mOff = offHRV.reduce(0, +) / Double(offHRV.count)
            guard mOff > 0 else { return nil }
            return ((mOn - mOff) / mOff) * 100.0
        }()

        let onRHR = onKeys.compactMap { rhrByDay[$0] }
        let offRHR = offKeys.isEmpty ? health.rhrHistory.filter { !onKeys.contains(Self.dayKey(for: $0.date)) }.map(\.value) : offKeys.compactMap { rhrByDay[$0] }
        let rhrDeltaBpm: Double? = {
            guard !onRHR.isEmpty, !offRHR.isEmpty else { return nil }
            return (onRHR.reduce(0, +) / Double(onRHR.count)) - (offRHR.reduce(0, +) / Double(offRHR.count))
        }()

        let onSleep = onKeys.compactMap { sleepByDay[$0] }
        let offSleep = offKeys.isEmpty ? health.sleepHistory.filter { !onKeys.contains(Self.dayKey(for: $0.date)) }.map(\.value) : offKeys.compactMap { sleepByDay[$0] }
        let sleepDeltaMin: Double? = {
            guard !onSleep.isEmpty, !offSleep.isEmpty else { return nil }
            return ((onSleep.reduce(0, +) / Double(onSleep.count)) - (offSleep.reduce(0, +) / Double(offSleep.count))) * 60.0
        }()

        let totalDays = onKeys.count + offKeys.count
        let verdict: String
        if totalDays < 3 {
            verdict = "Log \(max(0, 3 - totalDays)) more day(s) to pair HealthKit outcomes."
        } else if let hrvD = hrvDeltaPct, hrvD >= 5 {
            verdict = "Positive signal: HRV averages +\(Int(hrvD.rounded()))% higher on protocol days."
        } else if let rhrD = rhrDeltaBpm, rhrD <= -1.5 {
            verdict = "Positive signal: Resting HR drops \(String(format: "%.1f", abs(rhrD))) bpm on protocol days."
        } else {
            verdict = "Neutral delta so far across \(totalDays) logged days — keep testing through Day 14."
        }

        return ExperimentCorrelationSummary(
            onDaysCount: onKeys.count,
            offDaysCount: offKeys.count,
            hrvDeltaPct: hrvDeltaPct,
            rhrDeltaBpm: rhrDeltaBpm,
            sleepDeltaMin: sleepDeltaMin,
            verdict: verdict
        )
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(data, forKey: logsKey)
        }
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func dayKey(for date: Date) -> String {
        formatter.string(from: date)
    }
}

// MARK: - N-of-1 Experiment Lab Sheet
public struct ExperimentLabSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = ExperimentLabStore.shared
    @ObservedObject private var health = HealthKitManager.shared

    public init() {}

    public var body: some View {
        let active = store.activeProtocol
        let summary = store.correlation(for: active.id, health: health)
        let todayLog = store.todayStatus(for: active.id)

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    activeExperimentCard(active: active, summary: summary, todayLog: todayLog)
                    protocolPickerSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(ApexTheme.bg.ignoresSafeArea())
            .navigationTitle("N-of-1 Experiment Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func activeExperimentCard(active: ExperimentProtocol, summary: ExperimentCorrelationSummary, todayLog: Bool?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: active.icon)
                    .font(.title3)
                    .foregroundStyle(ApexTheme.orange)
                    .frame(width: 38, height: 38)
                    .background(ApexTheme.orange.opacity(0.16), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(active.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(active.subtitle)
                        .font(.caption)
                        .foregroundStyle(ApexTheme.secondaryText)
                }
                Spacer()
                Text("\(summary.onDaysCount)/14 d")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(ApexTheme.blue)
            }

            Text(active.hypothesis)
                .font(.subheadline)
                .foregroundStyle(ApexTheme.secondaryText)

            HStack(spacing: 10) {
                Button {
                    store.logToday(adhered: true)
                } label: {
                    Label(todayLog == true ? "Logged Done Today" : "Done Today", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(todayLog == true ? ApexTheme.green : ApexTheme.blue)

                Button {
                    store.logToday(adhered: false)
                } label: {
                    Label(todayLog == false ? "Logged Skipped" : "Control Day", systemImage: "minus.circle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(todayLog == false ? ApexTheme.orange : ApexTheme.secondaryText)
            }

            Divider().background(Color.white.opacity(0.08))

            HStack(spacing: 12) {
                outcomeStat(title: "HRV Δ", value: summary.hrvDeltaPct.map { String(format: "%+.0f%%", $0) } ?? "Need data", color: (summary.hrvDeltaPct ?? 0) >= 0 ? ApexTheme.green : ApexTheme.orange)
                outcomeStat(title: "RHR Δ", value: summary.rhrDeltaBpm.map { String(format: "%+.1f bpm", $0) } ?? "Need data", color: (summary.rhrDeltaBpm ?? 0) <= 0 ? ApexTheme.green : ApexTheme.red)
                outcomeStat(title: "Sleep Δ", value: summary.sleepDeltaMin.map { String(format: "%+.0f min", $0) } ?? "Need data", color: ApexTheme.blue)
            }

            Text(summary.verdict)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.top, 2)
        }
        .padding(18)
        .appleCard(cornerRadius: 20)
    }

    private func outcomeStat(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(ApexTheme.secondaryText)
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var protocolPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Available 14-Day Protocols")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)

            ForEach(ExperimentProtocol.presets) { proto in
                Button {
                    Haptics.selection()
                    store.activeProtocolId = proto.id
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: proto.icon)
                            .foregroundStyle(proto.id == store.activeProtocolId ? ApexTheme.blue : ApexTheme.secondaryText)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(proto.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(proto.subtitle)
                                .font(.caption)
                                .foregroundStyle(ApexTheme.secondaryText)
                        }
                        Spacer()
                        if proto.id == store.activeProtocolId {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(ApexTheme.blue)
                        }
                    }
                    .padding(14)
                    .appleCard(cornerRadius: 16)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
