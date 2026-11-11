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

public struct JournalTag: Identifiable, Codable, Hashable {
    public let id: String
    public let title: String
    public let icon: String
    public let category: String

    public static let presets: [JournalTag] = [
        JournalTag(id: "hydration", title: "Hydration", icon: "drop.fill", category: "Intake"),
        JournalTag(id: "caffeine_cutoff", title: "Caffeine Cutoff", icon: "cup.and.saucer.fill", category: "Intake"),
        JournalTag(id: "late_meal", title: "Late Meal", icon: "fork.knife", category: "Timing"),
        JournalTag(id: "alcohol", title: "Alcohol", icon: "wineglass.fill", category: "Intake"),
        JournalTag(id: "cold_plunge", title: "Cold Plunge", icon: "snowflake", category: "Recovery"),
        JournalTag(id: "sauna", title: "Sauna", icon: "flame.fill", category: "Recovery"),
        JournalTag(id: "sunlight", title: "Sunlight", icon: "sun.max.fill", category: "Circadian"),
        JournalTag(id: "magnesium", title: "Magnesium", icon: "pills.fill", category: "Supplement"),
        JournalTag(id: "creatine", title: "Creatine", icon: "bolt.fill", category: "Supplement"),
        JournalTag(id: "high_stress", title: "High Stress", icon: "waveform.path.ecg", category: "State"),
        JournalTag(id: "nasal_tape", title: "Nasal Tape", icon: "wind", category: "Sleep")
    ]
}

public struct JournalImpactSummary {
    public let tagId: String
    public let pairedDaysCount: Int
    public let baselineDaysCount: Int
    public let hrvDeltaPct: Double?
    public let rhrDeltaBpm: Double?
    public let sleepDeltaMin: Double?
    public let hasEnoughData: Bool
}

// MARK: - Store
@MainActor
public final class ExperimentLabStore: ObservableObject {
    public static let shared = ExperimentLabStore()

    @Published public var activeProtocolId: String {
        didSet { UserDefaults.standard.set(activeProtocolId, forKey: "apex_active_experiment_id") }
    }
    @Published public private(set) var logs: [ExperimentLogEntry] = []
    @Published public private(set) var dailyTagsByDate: [String: [String]] = [:]
    @Published public private(set) var customTags: [JournalTag] = []
    @Published public private(set) var customProtocols: [ExperimentProtocol] = []

    private let logsKey = "apex_experiment_logs_v1"
    private let journalTagsKey = "apex_daily_journal_tags_v1"
    private let customTagsKey = "apex_custom_journal_tags_v1"
    private let customProtocolsKey = "apex_custom_experiment_protocols_v1"

    private init() {
        self.activeProtocolId = UserDefaults.standard.string(forKey: "apex_active_experiment_id") ?? ExperimentProtocol.presets[0].id
        if let data = UserDefaults.standard.data(forKey: logsKey),
           let decoded = try? JSONDecoder().decode([ExperimentLogEntry].self, from: data) {
            self.logs = decoded
        }
        if let tagData = UserDefaults.standard.data(forKey: journalTagsKey),
           let decodedTags = try? JSONDecoder().decode([String: [String]].self, from: tagData) {
            self.dailyTagsByDate = decodedTags
        }
        if let customTagData = UserDefaults.standard.data(forKey: customTagsKey),
           let decodedCustomTags = try? JSONDecoder().decode([JournalTag].self, from: customTagData) {
            self.customTags = decodedCustomTags
        }
        if let customProtoData = UserDefaults.standard.data(forKey: customProtocolsKey),
           let decodedProtos = try? JSONDecoder().decode([ExperimentProtocol].self, from: customProtoData) {
            self.customProtocols = decodedProtos
        }
    }

    public var allTags: [JournalTag] {
        JournalTag.presets + customTags
    }

    public var allProtocols: [ExperimentProtocol] {
        ExperimentProtocol.presets + customProtocols
    }

    public var activeProtocol: ExperimentProtocol {
        allProtocols.first(where: { $0.id == activeProtocolId }) ?? ExperimentProtocol.presets[0]
    }

    public var dailyTagsToday: [String] {
        dailyTagsByDate[todayKey()] ?? []
    }

    public func tags(forDateKey key: String) -> [String] {
        dailyTagsByDate[key] ?? []
    }

    public func todayKey() -> String {
        Self.dayKey(for: Date())
    }

    public static func dateKey(daysAgo: Int) -> String {
        let d = Calendar(identifier: .gregorian).date(byAdding: .day, value: -max(0, daysAgo), to: Date()) ?? Date()
        return dayKey(for: d)
    }

    public func addCustomTag(title: String, icon: String = "tag.fill", category: String = "Custom") {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let slug = "custom_" + trimmed.lowercased().replacingOccurrences(of: " ", with: "_") + "_\(Int(Date().timeIntervalSince1970) % 10000)"
        let tag = JournalTag(id: slug, title: trimmed, icon: icon, category: category)
        customTags.append(tag)
        persist()
        Haptics.success()
    }

    public func addCustomProtocol(title: String, subtitle: String, hypothesis: String, icon: String = "flask.fill") {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let pid = "custom_proto_\(Int(Date().timeIntervalSince1970))"
        let proto = ExperimentProtocol(
            id: pid,
            title: trimmed,
            subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "14-day N-of-1 test" : subtitle,
            hypothesis: hypothesis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Measures Lag-1 next-morning HRV, RHR & sleep delta." : hypothesis,
            icon: icon,
            accentHex: "#00F0FF"
        )
        customProtocols.append(proto)
        activeProtocolId = pid
        persist()
        Haptics.success()
    }

    public func toggleJournalTag(_ tagId: String, dateKey: String? = nil) {
        let key = dateKey ?? todayKey()
        var current = dailyTagsByDate[key] ?? []
        if let idx = current.firstIndex(of: tagId) {
            current.remove(at: idx)
        } else {
            current.append(tagId)
        }
        dailyTagsByDate[key] = current
        persist()
        Haptics.selection()
        HealthKitManager.shared.persistWidgetSnapshot()

        HealthKitManager.shared.syncEventToMac(extraPayload: [
            "journalTagsToday": dailyTagsToday,
            "dailyTagsByDate": dailyTagsByDate
        ])
    }

    public func logToday(adhered: Bool, dateKey: String? = nil) {
        let key = dateKey ?? todayKey()
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

    public func todayStatus(for protocolId: String, dateKey: String? = nil) -> Bool? {
        let key = dateKey ?? todayKey()
        return logs.first(where: { $0.dateKey == key && $0.protocolId == protocolId })?.adhered
    }

    /// Lag-1 next-morning causality (protocol logged on day D -> paired with HealthKit morning outcomes on day D+1).
    public func correlation(for protocolId: String, health: HealthKitManager) -> ExperimentCorrelationSummary {
        let relevantLogs = logs.filter { $0.protocolId == protocolId }
        let rawOn = Set(relevantLogs.filter { $0.adhered }.map { $0.dateKey })
        let rawOff = Set(relevantLogs.filter { !$0.adhered }.map { $0.dateKey })

        let nextOnKeys = ApexBiometricMath.lag1ShiftedKeys(rawOn)
        let nextOffKeys = ApexBiometricMath.lag1ShiftedKeys(rawOff)
        let deltas = computeOutcomeDeltas(onKeys: nextOnKeys, offKeys: nextOffKeys, health: health)

        let totalDays = rawOn.count + rawOff.count
        let verdict: String
        if rawOn.isEmpty && rawOff.isEmpty {
            verdict = "Log both Protocol On and Control Off days across 14 days to pair next-morning (D+1) HealthKit outcomes."
        } else if rawOff.count < 2 || rawOn.count < 2 {
            verdict = "Logged \(rawOn.count) On / \(rawOff.count) Control day(s). Log at least 2 On and 2 Control days for balanced Lag-1 pairing."
        } else if let hrvD = deltas.hrvDeltaPct, hrvD >= 5 {
            verdict = "Positive Lag-1 signal: next-morning HRV averages +\(Int(hrvD.rounded()))% higher."
        } else if let rhrD = deltas.rhrDeltaBpm, rhrD <= -1.5 {
            verdict = "Positive Lag-1 signal: overnight RHR drops \(String(format: "%.1f", abs(rhrD))) bpm."
        } else {
            verdict = "Neutral Lag-1 delta across \(totalDays) logged days — keep logging through Day 14."
        }

        return ExperimentCorrelationSummary(
            onDaysCount: rawOn.count,
            offDaysCount: rawOff.count,
            hrvDeltaPct: (rawOn.count >= 2 && rawOff.count >= 2) ? deltas.hrvDeltaPct : nil,
            rhrDeltaBpm: (rawOn.count >= 2 && rawOff.count >= 2) ? deltas.rhrDeltaBpm : nil,
            sleepDeltaMin: (rawOn.count >= 2 && rawOff.count >= 2) ? deltas.sleepDeltaMin : nil,
            verdict: verdict
        )
    }

    /// Lag-1 correlation: pairs a tag logged on day D against next-day (D+1) HRV, RHR, and Sleep outcomes.
    public func journalCorrelation(forTagId tagId: String, health: HealthKitManager) -> JournalImpactSummary {
        let cal = Calendar(identifier: .gregorian)
        var taggedNextKeys = Set<String>()
        var untaggedLoggedNextKeys = Set<String>()

        for (key, tags) in dailyTagsByDate {
            guard let tagDate = Self.formatter.date(from: key),
                  let nextDate = cal.date(byAdding: .day, value: 1, to: tagDate) else { continue }
            let nextKey = Self.dayKey(for: nextDate)
            if tags.contains(tagId) {
                taggedNextKeys.insert(nextKey)
            } else {
                untaggedLoggedNextKeys.insert(nextKey)
            }
        }

        let healthKeys = Set(health.hrvHistory.map { Self.dayKey(for: $0.date) })
            .union(health.rhrHistory.map { Self.dayKey(for: $0.date) })
            .union(health.sleepHistory.map { Self.dayKey(for: $0.date) })

        let baselineKeys = untaggedLoggedNextKeys.isEmpty
            ? healthKeys.subtracting(taggedNextKeys)
            : untaggedLoggedNextKeys

        let pairedWithOutcomeCount = taggedNextKeys.intersection(healthKeys).count
        let enoughData = pairedWithOutcomeCount >= 3 && !baselineKeys.intersection(healthKeys).isEmpty

        let deltas = enoughData
            ? computeOutcomeDeltas(onKeys: taggedNextKeys, offKeys: baselineKeys, health: health)
            : (hrvDeltaPct: nil, rhrDeltaBpm: nil, sleepDeltaMin: nil)

        return JournalImpactSummary(
            tagId: tagId,
            pairedDaysCount: pairedWithOutcomeCount,
            baselineDaysCount: baselineKeys.intersection(healthKeys).count,
            hrvDeltaPct: deltas.hrvDeltaPct,
            rhrDeltaBpm: deltas.rhrDeltaBpm,
            sleepDeltaMin: deltas.sleepDeltaMin,
            hasEnoughData: enoughData
        )
    }

    private func computeOutcomeDeltas(onKeys: Set<String>, offKeys: Set<String>, health: HealthKitManager) -> (hrvDeltaPct: Double?, rhrDeltaBpm: Double?, sleepDeltaMin: Double?) {
        let hrvByDay = Dictionary(health.hrvHistory.map { (Self.dayKey(for: $0.date), $0.value) }, uniquingKeysWith: { _, latest in latest })
        let rhrByDay = Dictionary(health.rhrHistory.map { (Self.dayKey(for: $0.date), $0.value) }, uniquingKeysWith: { _, latest in latest })
        let sleepByDay = Dictionary(health.sleepHistory.map { (Self.dayKey(for: $0.date), $0.value) }, uniquingKeysWith: { _, latest in latest })

        let hrvDeltaPct = ApexBiometricMath.meanPercentDelta(
            onValues: onKeys.compactMap { hrvByDay[$0] },
            offValues: offKeys.compactMap { hrvByDay[$0] }
        )
        let rhrDeltaBpm = ApexBiometricMath.meanAbsoluteDelta(
            onValues: onKeys.compactMap { rhrByDay[$0] },
            offValues: offKeys.compactMap { rhrByDay[$0] }
        )
        let sleepDeltaMin = ApexBiometricMath.meanAbsoluteDelta(
            onValues: onKeys.compactMap { sleepByDay[$0] },
            offValues: offKeys.compactMap { sleepByDay[$0] },
            scale: 60.0
        )

        return (hrvDeltaPct, rhrDeltaBpm, sleepDeltaMin)
    }

    public func reloadFromDisk() {
        self.activeProtocolId = UserDefaults.standard.string(forKey: "apex_active_experiment_id") ?? ExperimentProtocol.presets[0].id
        if let data = UserDefaults.standard.data(forKey: logsKey),
           let decoded = try? JSONDecoder().decode([ExperimentLogEntry].self, from: data) {
            self.logs = decoded
        }
        if let tagData = UserDefaults.standard.data(forKey: journalTagsKey),
           let decodedTags = try? JSONDecoder().decode([String: [String]].self, from: tagData) {
            self.dailyTagsByDate = decodedTags
        }
        if let customTagData = UserDefaults.standard.data(forKey: customTagsKey),
           let decodedCustomTags = try? JSONDecoder().decode([JournalTag].self, from: customTagData) {
            self.customTags = decodedCustomTags
        }
        if let customProtoData = UserDefaults.standard.data(forKey: customProtocolsKey),
           let decodedProtos = try? JSONDecoder().decode([ExperimentProtocol].self, from: customProtoData) {
            self.customProtocols = decodedProtos
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(data, forKey: logsKey)
        }
        if let tagData = try? JSONEncoder().encode(dailyTagsByDate) {
            UserDefaults.standard.set(tagData, forKey: journalTagsKey)
        }
        if let customTagData = try? JSONEncoder().encode(customTags) {
            UserDefaults.standard.set(customTagData, forKey: customTagsKey)
        }
        if let customProtoData = try? JSONEncoder().encode(customProtocols) {
            UserDefaults.standard.set(customProtoData, forKey: customProtocolsKey)
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

    @State private var selectedDaysAgo: Int = 0
    @State private var showNewTagSheet = false
    @State private var newTagTitle = ""
    @State private var showNewProtoSheet = false
    @State private var newProtoTitle = ""
    @State private var newProtoSubtitle = ""
    @State private var newProtoHypothesis = ""

    public init() {}

    private var selectedDateKey: String {
        ExperimentLabStore.dateKey(daysAgo: selectedDaysAgo)
    }

    private var selectedDayLabel: String {
        if selectedDaysAgo == 0 { return "Today" }
        if selectedDaysAgo == 1 { return "Yesterday" }
        return "\(selectedDaysAgo)d ago"
    }

    public var body: some View {
        let active = store.activeProtocol
        let summary = store.correlation(for: active.id, health: health)
        let dayLog = store.todayStatus(for: active.id, dateKey: selectedDateKey)

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    dateBackfillPicker
                    dailyJournalSection
                    activeExperimentCard(active: active, summary: summary, todayLog: dayLog)
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
            .alert("Create Custom Journal Tag", isPresented: $showNewTagSheet) {
                TextField("Tag name (e.g. Electrolytes, Sauna)", text: $newTagTitle)
                Button("Add Tag") {
                    store.addCustomTag(title: newTagTitle)
                    newTagTitle = ""
                }
                Button("Cancel", role: .cancel) { newTagTitle = "" }
            }
            .sheet(isPresented: $showNewProtoSheet) {
                NavigationStack {
                    Form {
                        Section("Protocol Details") {
                            TextField("Protocol Title (e.g. Magnesium Before Bed)", text: $newProtoTitle)
                            TextField("Target Mechanism (e.g. Deep sleep latency)", text: $newProtoSubtitle)
                            TextField("Hypothesis", text: $newProtoHypothesis)
                        }
                    }
                    .navigationTitle("New 14-Day Protocol")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") { showNewProtoSheet = false }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Save") {
                                store.addCustomProtocol(title: newProtoTitle, subtitle: newProtoSubtitle, hypothesis: newProtoHypothesis)
                                newProtoTitle = ""
                                newProtoSubtitle = ""
                                newProtoHypothesis = ""
                                showNewProtoSheet = false
                            }
                            .disabled(newProtoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .preferredColorScheme(.dark)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var dateBackfillPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { daysAgo in
                    let label = daysAgo == 0 ? "Today" : (daysAgo == 1 ? "Yesterday" : ExperimentLabStore.dateKey(daysAgo: daysAgo).suffix(5).description)
                    let isSelected = selectedDaysAgo == daysAgo
                    Button {
                        selectedDaysAgo = daysAgo
                        Haptics.selection()
                    } label: {
                        Text(label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isSelected ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isSelected ? ApexTheme.accentVolt : ApexTheme.cardSurface)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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
                    store.logToday(adhered: true, dateKey: selectedDateKey)
                } label: {
                    Label(todayLog == true ? "Logged Done (\(selectedDayLabel))" : "Done (\(selectedDayLabel))", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(todayLog == true ? ApexTheme.green : ApexTheme.blue)

                Button {
                    store.logToday(adhered: false, dateKey: selectedDateKey)
                } label: {
                    Label(todayLog == false ? "Logged Skipped (\(selectedDayLabel))" : "Control (\(selectedDayLabel))", systemImage: "minus.circle")
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

    private var dailyJournalSection: some View {
        let activeTags = Set(store.tags(forDateKey: selectedDateKey))
        let columns = [GridItem(.adaptive(minimum: 120), spacing: 8)]

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Journal · \(selectedDayLabel)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Lag-1 pairs against next-day HRV, RHR & Sleep")
                        .font(.caption)
                        .foregroundStyle(ApexTheme.secondaryText)
                }
                Spacer()
                Button {
                    showNewTagSheet = true
                } label: {
                    Label("Tag", systemImage: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ApexTheme.accentVolt)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(ApexTheme.accentVolt.opacity(0.14), in: Capsule())
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(store.allTags) { tag in
                    let isOn = activeTags.contains(tag.id)
                    Button {
                        store.toggleJournalTag(tag.id, dateKey: selectedDateKey)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tag.icon)
                                .font(.caption.weight(.semibold))
                            Text(tag.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 8)
                        .foregroundStyle(isOn ? .white : ApexTheme.secondaryText)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isOn ? ApexTheme.blue.opacity(0.28) : Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isOn ? ApexTheme.blue : Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().background(Color.white.opacity(0.08))

            let taggedPresets = store.allTags.filter { tag in
                store.dailyTagsByDate.values.contains(where: { $0.contains(tag.id) })
            }
            if taggedPresets.isEmpty {
                Text("Log tags across ≥3 days alongside Apple Health sleep & HRV to unlock Lag-1 impact coefficients.")
                    .font(.caption)
                    .foregroundStyle(ApexTheme.secondaryText)
            } else {
                VStack(spacing: 8) {
                    ForEach(taggedPresets) { tag in
                        let impact = store.journalCorrelation(forTagId: tag.id, health: health)
                        HStack(spacing: 10) {
                            Image(systemName: tag.icon)
                                .foregroundStyle(ApexTheme.blue)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(tag.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(impact.hasEnoughData
                                     ? "Paired \(impact.pairedDaysCount)d vs \(impact.baselineDaysCount)d base"
                                     : "Paired \(impact.pairedDaysCount)/3 days needed")
                                    .font(.caption2)
                                    .foregroundStyle(ApexTheme.secondaryText)
                            }
                            Spacer()
                            if impact.hasEnoughData {
                                HStack(spacing: 8) {
                                    if let hrvD = impact.hrvDeltaPct {
                                        Text(String(format: "%+.0f%% HRV", hrvD))
                                            .font(.caption.weight(.bold).monospacedDigit())
                                            .foregroundStyle(hrvD >= 0 ? ApexTheme.green : ApexTheme.orange)
                                    }
                                    if let rhrD = impact.rhrDeltaBpm {
                                        Text(String(format: "%+.1f RHR", rhrD))
                                            .font(.caption.weight(.bold).monospacedDigit())
                                            .foregroundStyle(rhrD <= 0 ? ApexTheme.green : ApexTheme.red)
                                    }
                                }
                            } else {
                                Text("Needs ≥3d")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(ApexTheme.secondaryText)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
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
            HStack {
                Text("Available 14-Day Protocols")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    showNewProtoSheet = true
                } label: {
                    Label("Custom Protocol", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ApexTheme.standCyan)
                }
            }
            .padding(.horizontal, 4)

            ForEach(store.allProtocols) { proto in
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
