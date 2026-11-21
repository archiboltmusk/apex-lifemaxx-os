import SwiftUI
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

public struct CoachMessage: Identifiable, Equatable, Codable {
    public let id: UUID
    public let isUser: Bool
    public let text: String
    public let timestamp: Date

    public init(id: UUID = UUID(), isUser: Bool, text: String, timestamp: Date = Date()) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.timestamp = timestamp
    }
}

// MARK: - Private On-Device Apple Intelligence Physician & Protocol Q&A Engine
@MainActor
public final class ApexIntelligenceEngine: ObservableObject {
    public static let shared = ApexIntelligenceEngine()

    private static let storageKey = "apex_ios_coach_messages_v1"

    @Published public var messages: [CoachMessage] = []
    @Published public var isThinking: Bool = false
    @Published public var engineLabel: String = "On-Device Protocol Engine"
    @Published public var appleIntelligenceAvailable: Bool = false

    private init() {
        loadMessages()
        refreshAvailability()
    }

    public func clearMessages() {
        messages.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    public func replaceMessages(_ loaded: [CoachMessage]) {
        messages = loaded
        persistMessages()
    }

    private func loadMessages() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([CoachMessage].self, from: data) else { return }
        messages = decoded
    }

    private func persistMessages() {
        let trimmed = messages.suffix(60)
        if let encoded = try? JSONEncoder().encode(Array(trimmed)) {
            UserDefaults.standard.set(encoded, forKey: Self.storageKey)
        }
    }

    public func refreshAvailability() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if SystemLanguageModel.default.availability == .available {
                appleIntelligenceAvailable = true
                engineLabel = "Apple Intelligence (On-Device)"
                return
            }
        }
        #endif
        appleIntelligenceAvailable = false
        engineLabel = "APEX Clinical Rule Engine"
    }

    public func ask(_ question: String, health: HealthKitManager) async {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(CoachMessage(isUser: true, text: trimmed))
        persistMessages()
        isThinking = true
        refreshAvailability()

        let context = buildBiometricContext(health: health)

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), SystemLanguageModel.default.availability == .available {
            do {
                let session = LanguageModelSession(
                    instructions: """
                    You are APEX Intelligence, a concise, evidence-based longevity physician and strength coach.
                    Answer cleanly using only the user's real telemetry provided below. Never invent numbers.
                    Keep answers under 90 words, calm and practical, Apple Health style.
                    """
                )
                let prompt = "\(context)\n\nUser Question: \(trimmed)"
                let response = try await session.respond(to: prompt)
                messages.append(CoachMessage(isUser: false, text: response.content))
                persistMessages()
                isThinking = false
                return
            } catch {
                // Fall through cleanly to local clinical synthesis
            }
        }
        #endif

        // Deterministic On-Device Clinical Synthesis (Guaranteed Private Fallback)
        let answer = synthesizeLocalClinicalReply(question: trimmed, health: health)
        try? await Task.sleep(nanoseconds: 250_000_000)
        messages.append(CoachMessage(isUser: false, text: answer))
        persistMessages()
        isThinking = false
    }

    private func buildBiometricContext(health: HealthKitManager) -> String {
        let nutrition = NutritionLogStore.shared
        let tagsToday = ExperimentLabStore.shared.dailyTagsToday
        let monitor = health.vitalRangeSummary
        let labPanel = LabPanelStore.load()

        var lines: [String] = ["Current Telemetry:"]
        lines.append("- Unit System: \(ApexUnitPreferences.current == .imperial ? "Imperial (lbs, mmol/L, fl oz)" : "Metric (kg, mg/dL, mL)")")
        lines.append("- Recovery Readiness: \(health.readinessScore.map { "\($0)%" } ?? "Unrecorded")")
        lines.append("- Daily Strain: \(health.todayStrainScore.map { String(format: "%.1f / 21", $0) } ?? "Unrecorded") (Target: \(health.targetStrainRange.map { String(format: "%.0f–%.0f", $0.lowerBound, $0.upperBound) } ?? "n/a"))")
        lines.append("- Energy Bank: \(health.energyBankPercent.map { "\($0)%" } ?? "Unrecorded")")
        lines.append("- Intraday Stress: \(health.currentStressScore.map { "\($0)/100" } ?? "Unrecorded")")
        lines.append("- Move: \(Int(health.moveCalories))/\(Int(health.moveTarget)) kcal, Exercise: \(Int(health.exerciseMinutes))m, Steps: \(health.dailySteps)")
        if let rhr = health.restingHeartRate {
            lines.append("- Resting HR: \(Int(rhr.rounded())) bpm (7d delta: \(health.rhrDeltaBpm.map { "\($0) bpm" } ?? "n/a"))")
        }
        if let hrv = health.heartRateVariability {
            lines.append("- HRV SDNN: \(Int(hrv.rounded())) ms (7d delta: \(health.hrvDeltaPercent.map { "\($0)%" } ?? "n/a"))")
        }
        if let vo2 = health.vo2Max {
            lines.append("- VO2 Max: \(String(format: "%.1f", vo2)) mL/kg*min")
        }
        if let sleep = health.sleepTotalHours {
            lines.append("- Sleep: \(String(format: "%.1f", sleep))h (Deep \(String(format: "%.1f", health.sleepDeepHours))h, REM \(String(format: "%.1f", health.sleepRemHours))h)")
        }
        if let needed = health.sleepNeededHours {
            lines.append("- Sleep Needed Tonight: \(String(format: "%.1f", needed))h (7d Debt: \(health.sleepDebtHours.map { String(format: "%+.1fh", $0) } ?? "n/a"))")
        }
        if monitor.total > 0 {
            lines.append("- 5-Vital Health Monitor: \(monitor.inRange)/\(monitor.total) vitals in personal range")
        }
        if let fat = health.bodyFatPercent {
            lines.append("- Body Fat: \(String(format: "%.1f%%", fat)), Lean Mass: \(health.leanBodyMassKg.map { ApexUnitPreferences.formatWeight(kg: $0) } ?? "n/a")")
        }
        if let glucose = health.glucoseSamples24h.last {
            lines.append("- Latest Glucose: \(ApexUnitPreferences.formatGlucose(mgDl: glucose.value))")
        }
        if let nScore = nutrition.nutritionQualityScore {
            lines.append("- Nutrition Quality Score: \(nScore)/100 (\(Int(nutrition.todayCalories.rounded())) kcal, \(Int(nutrition.todayProtein.rounded()))g P, Water \(ApexUnitPreferences.formatVolume(ml: nutrition.waterMlToday)), Caffeine \(Int(nutrition.caffeineMgToday.rounded()))mg)")
        }
        if !tagsToday.isEmpty {
            lines.append("- Daily Journal Tags Today: \(tagsToday.joined(separator: ", "))")
        }
        if let bio = health.biologicalAge {
            lines.append("- Fitness Biological Age: \(String(format: "%.1f", bio))y vs Chronological \(Int(health.chronologicalAge))y")
        }
        if let pace = health.paceOfAging {
            lines.append("- Pace of Aging: \(String(format: "%.2f", pace)) yr/yr")
        }
        if let clinical = health.clinicalPhenoAge {
            lines.append("- Bloodwork Levine PhenoAge: \(String(format: "%.1f", clinical))y")
        }
        if let labPanel {
            var extended: [String] = []
            if let apoB = labPanel.apoBMgDL { extended.append("ApoB \(Int(apoB)) mg/dL") }
            if let a1c = labPanel.hba1cPct { extended.append("HbA1c \(String(format: "%.1f%%", a1c))") }
            if let vitD = labPanel.vitaminDNgML { extended.append("VitD \(Int(vitD)) ng/mL") }
            if let t = labPanel.totalTestosteroneNgDL { extended.append("TotalT \(Int(t)) ng/dL") }
            if !extended.isEmpty {
                lines.append("- Extended Lab Markers: \(extended.joined(separator: ", "))")
            }
        }
        if let acwr = health.acwrResult {
            lines.append("- ACWR Workload Ratio: \(String(format: "%.2f", acwr.ratio)) (\(acwr.zone.rawValue))")
        }
        if let cardio = health.cardiovascularAgeResult {
            lines.append("- Cardiovascular Age: \(String(format: "%.1f", cardio.cardiovascularAge))y (\(cardio.elasticityStatus))")
        }
        if let circ = health.circadianProfile {
            lines.append("- Chronotype: \(circ.chronotype.rawValue), Optimal Bedtime: \(circ.optimalBedtimeFormatted), Regularity: \(circ.regularityScore)%")
        }
        let tdeeRes = nutrition.adaptiveTDEEResult(health: health)
        lines.append("- Adaptive TDEE: \(Int(tdeeRes.calculatedTDEE)) kcal/day (Deficit: \(Int(tdeeRes.fatLossTargetKcal)), Surplus: \(Int(tdeeRes.leanBulkTargetKcal)))")
        if let sc = health.organScorecard {
            lines.append("- Organ Longevity Composite: \(String(format: "%.1f", sc.compositeAge))y across 6 pillars")
        }
        return lines.joined(separator: "\n")
    }

    private func synthesizeLocalClinicalReply(question: String, health: HealthKitManager) -> String {
        let lower = question.lowercased()
        let nutrition = NutritionLogStore.shared
        let strength = StrengthBuilderStore.shared
        let brain = ThermalBrainStore.shared
        let labPanel = LabPanelStore.load()

        if lower.contains("acwr") || lower.contains("workload") || lower.contains("overtrain") || lower.contains("injury") {
            if let acwr = health.acwrResult {
                return "ACWR Workload Ratio is \(String(format: "%.2f", acwr.ratio)) (\(acwr.zone.rawValue)). Acute 7d load: \(String(format: "%.1f", acwr.acuteLoad7d)), Chronic 28d load: \(String(format: "%.1f", acwr.chronicLoad28d)). \(acwr.recommendation)"
            }
            return "Acute:Chronic Workload Ratio requires at least 2 days of movement data in Apple Health to compute 7d vs 28d strain loads."
        }

        if lower.contains("cardio age") || lower.contains("vascular") || lower.contains("artery") || lower.contains("arterial") {
            if let cardio = health.cardiovascularAgeResult {
                let deltaText = cardio.ageDelta <= 0 ? String(format: "%.1fy younger than chronological age", abs(cardio.ageDelta)) : String(format: "+%.1fy above baseline", cardio.ageDelta)
                return "Cardiovascular Age is \(String(format: "%.1f", cardio.cardiovascularAge)) years (\(deltaText)). Status: \(cardio.elasticityStatus). \(cardio.recommendation)"
            }
            return "Cardiovascular Age model combines your VO2 Max, Resting HR, and HRV vagal tone. Connect Apple Health or record a workout to calibrate."
        }

        if lower.contains("chronotype") || lower.contains("circadian") || lower.contains("bedtime") || lower.contains("melatonin") {
            if let circ = health.circadianProfile {
                return "Your biological chronotype is \(circ.chronotype.rawValue) (Sleep Midpoint: \(circ.sleepMidpointFormatted), Regularity: \(circ.regularityScore)%). Optimal bedtime window is \(circ.optimalBedtimeFormatted), with melatonin onset around \(circ.melatoninWindowStartFormatted) and natural wake around \(circ.optimalWakeFormatted)."
            }
            return "Circadian alignment analyzes your rolling sleep midpoint regularity. Connect sleep history in Apple Health to pinpoint your optimal bedtime."
        }

        if lower.contains("tdee") || lower.contains("expenditure") || lower.contains("deficit") || lower.contains("bulk") || lower.contains("cut") {
            let tdee = nutrition.adaptiveTDEEResult(health: health)
            return "Adaptive Dynamic TDEE: \(Int(tdee.calculatedTDEE)) kcal/day. Automated Targets: Fat Loss Deficit (-20%) is \(Int(tdee.fatLossTargetKcal)) kcal with \(Int(tdee.recommendedProteinG))g protein; Lean Mass (+10%) is \(Int(tdee.leanBulkTargetKcal)) kcal. Tap TDEE in Fuel to apply with one tap."
        }

        if lower.contains("organ") || lower.contains("blueprint") || lower.contains("pillars") {
            if let sc = health.organScorecard {
                return "Organ Age Scorecard: Composite age is \(String(format: "%.1f", sc.compositeAge))y across 6 biological pillars. Cardiovascular: \(String(format: "%.1fy", sc.pillars[0].age)), Metabolic: \(String(format: "%.1fy", sc.pillars[1].age)), Autonomic: \(String(format: "%.1fy", sc.pillars[2].age)), Musculoskeletal: \(String(format: "%.1fy", sc.pillars[3].age)), Immune: \(String(format: "%.1fy", sc.pillars[4].age)), Epigenetic: \(String(format: "%.1fy", sc.pillars[5].age))."
            }
            return "Organ Age Scorecard requires baseline vitals and bloodwork. Open Biology to inspect your 6 longevity pillars."
        }

        if lower.contains("sleep") || lower.contains("deep") || lower.contains("rem") || lower.contains("debt") {
            guard let sleep = health.sleepTotalHours else {
                return "No overnight sleep stage samples are stored in Apple Health yet. Wear Apple Watch overnight or connect HealthKit to analyze Deep, REM, and Sleep Debt."
            }
            let needText = health.sleepNeededHours.map { String(format: " Target tonight: %.1fh (7d debt %+.1fh).", $0, health.sleepDebtHours ?? 0) } ?? ""
            return String(
                format: "You logged %.1fh sleep (%.1fh Deep, %.1fh REM).%@ %@ Anchor wake timing consistently and finish heavy meals 3h before bed.",
                sleep, health.sleepDeepHours, health.sleepRemHours, needText,
                health.sleepDeepHours < 1.2 ? "Deep sleep is below optimal (>1.4h)." : "Deep sleep architecture looks solid."
            )
        }

        if lower.contains("caffeine") || lower.contains("coffee") || lower.contains("hydrat") || lower.contains("water") || lower.contains("sodium") {
            let waterStr = ApexUnitPreferences.formatVolume(ml: nutrition.waterMlToday)
            let targetStr = ApexUnitPreferences.formatVolume(ml: nutrition.waterTargetMl)
            let activeCaf = nutrition.activeCaffeineRemainingMg
            return "Hydration today is \(waterStr) / \(targetStr) target with \(Int(nutrition.todaySodiumMg.rounded())) mg logged sodium. Total caffeine: \(Int(nutrition.caffeineMgToday.rounded())) mg (active blood caffeine remaining right now: ~\(Int(activeCaf.rounded())) mg via 5.7h half-life decay)."
        }

        if lower.contains("energy") || lower.contains("stress") || lower.contains("battery") || lower.contains("strain") {
            let energyStr = health.energyBankPercent.map { "\($0)% Energy Bank" } ?? "Energy Bank pending HealthKit"
            let stressStr = health.currentStressScore.map { "\($0)/100 current stress" } ?? "Stress pending HR/HRV"
            let strainStr = health.todayStrainScore.map { String(format: "%.1f/21 Strain", $0) } ?? "Strain pending movement"
            return "Live Autonomic Balance: \(energyStr), \(stressStr), \(strainStr). \(health.energyBankPercent.map { $0 < 40 ? "Consider a 20m NSDR/power nap or nasal Zone 2 decompression to recharge reserves." : "Metabolic reserve supports focused training or cognitive blocks." } ?? "Connect HealthKit on Summary for live Bevel curves.")"
        }

        if lower.contains("fuel") || lower.contains("nutri") || lower.contains("macro") || lower.contains("glucose") || lower.contains("cgm") || lower.contains("meal") || lower.contains("protein") {
            if let qScore = nutrition.nutritionQualityScore {
                let cgmStr = health.glucoseSamples24h.last.map { " Latest CGM glucose: \(ApexUnitPreferences.formatGlucose(mgDl: $0.value))." } ?? ""
                return "Today's Nutrition Quality Score is \(qScore)/100 across \(Int(nutrition.todayCalories.rounded())) kcal and \(Int(nutrition.todayProtein.rounded()))g protein (\(ApexUnitPreferences.formatVolume(ml: nutrition.waterMlToday)) water).\(cgmStr) Keep protein >=1.6g/\(ApexUnitPreferences.weightUnitLabel == "lbs" ? "lb target" : "kg") and walk 15 min after high-GL meals."
            }
            return "No meals logged in Fuel today. Scan a barcode, snap a nutrition label, or describe a meal in the Fuel tab to compute your Nutrition Quality Score and CGM response."
        }

        if lower.contains("pheno") || lower.contains("lab") || lower.contains("blood") || lower.contains("apob") || lower.contains("a1c") || lower.contains("testosterone") || lower.contains("pace") {
            var parts: [String] = []
            if let clinical = health.clinicalPhenoAge {
                let diff = clinical - health.chronologicalAge
                parts.append(String(format: "Clinical PhenoAge: %.1f yrs (%+.1f vs chronological %d yrs).", clinical, diff, Int(health.chronologicalAge)))
            }
            if let pace = health.paceOfAging {
                parts.append(String(format: "Dunedin Pace of Aging: %.2f yr/yr.", pace))
            }
            if let labPanel {
                if let apoB = labPanel.apoBMgDL { parts.append("ApoB \(Int(apoB)) mg/dL (target <80).") }
                if let a1c = labPanel.hba1cPct { parts.append(String(format: "HbA1c %.1f%% (target <5.3%%).", a1c)) }
                if let vitD = labPanel.vitaminDNgML { parts.append("Vit D \(Int(vitD)) ng/mL.") }
                if let t = labPanel.totalTestosteroneNgDL { parts.append("Total T \(Int(t)) ng/dL.") }
            }
            if !parts.isEmpty {
                return parts.joined(separator: " ") + " Focus on Zone 2 aerobic base, visceral fat reduction, and anti-inflammatory recovery."
            }
            return "No bloodwork lab panel has been scanned yet. Open Biology -> Bloodwork OCR to scan a PDF or paper slip for your PhenoAge, ApoB, HbA1c, Vitamin D, and Testosterone analysis."
        }

        if lower.contains("face") || lower.contains("voice") || lower.contains("posture") || lower.contains("sauna") || lower.contains("cold") || lower.contains("n-back") {
            let faceCount = FaceScanStore.load().count
            let voice = VoiceBiomarkerStore.shared.latest
            let voiceText = voice.map { v -> String in
                let cnsStr = v.cnsStressScore.map { " (CNS score \($0)/100)" } ?? ""
                return String(format: "Latest vocal F0: %.0f Hz%@.", v.fundamentalPitchHz, cnsStr)
            } ?? "No 5s voice check logged yet."
            let thermalCount = brain.thermalSessions.count
            let nback = brain.nBackSessions.first.map { "Best recent N-Back: \($0.nLevel)-Back at \($0.accuracyPct)%." } ?? ""
            return "Structural & Neural Lab: \(faceCount) facial symmetry scans saved, \(thermalCount) thermal sessions logged. \(voiceText) \(nback)".trimmingCharacters(in: .whitespaces)
        }

        if lower.contains("train") || lower.contains("workout") || lower.contains("squat") || lower.contains("push") || lower.contains("strength") || lower.contains("pr") || lower.contains("1rm") {
            let recentSets = WorkoutSetStore.load().count
            let recentSessions = strength.completedWorkouts.count
            if let delta = health.hrvDeltaPercent, delta <= -12 {
                return "HRV is \(delta)% below your 7-day baseline (\(recentSessions) logged strength sessions, \(recentSets) optical VBT sets). Swap high-CNS maximal squats today for 35 minutes of nasal Zone 2 incline walking (128–140 bpm) or light mobility."
            }
            if let rdy = health.readinessScore, rdy >= 78 {
                let targetText = health.targetStrainRange.map { String(format: " Aim for %.0f–%.0f Daily Strain.", $0.lowerBound, $0.upperBound) } ?? ""
                return "Autonomic readiness is strong at \(rdy)%.\(targetText) Prime window for Strength Builder progression or Optical Train velocity sets."
            }
            return "Use Strength Builder (\(recentSessions) sessions) or Optical Train (\(recentSets) VBT sets) today: warm up clean, log RPE accurately, and respect your target strain zone."
        }

        if lower.contains("journal") || lower.contains("experiment") || lower.contains("tag") || lower.contains("hrv") || lower.contains("rhr") {
            let hrvStr = health.heartRateVariability.map { "\(Int($0.rounded())) ms" } ?? "unrecorded HRV"
            let rhrStr = health.restingHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "unrecorded RHR"
            let tagsToday = ExperimentLabStore.shared.dailyTagsToday
            let tagText = tagsToday.isEmpty ? "No habit tags toggled today." : "Logged today: \(tagsToday.joined(separator: ", "))."
            return "Autonomic baseline: \(hrvStr) HRV (7d delta: \(health.hrvDeltaPercent.map { "\($0)%" } ?? "n/a")), \(rhrStr) RHR. \(tagText) Check Biology -> Experiment Lab for true Day D -> D+1 next-day HRV causality."
        }

        if let rdy = health.readinessScore {
            let hrvStr = health.heartRateVariability.map { "\(Int($0.rounded())) ms" } ?? "no HRV reading"
            let rhrStr = health.restingHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "no RHR reading"
            let extraEnergy = health.energyBankPercent.map { " Energy Bank is at \($0)%." } ?? ""
            return "Recovery Readiness is \(rdy)% (\(hrvStr) HRV, \(rhrStr) RHR).\(extraEnergy) Check your Daily Journal tags in Biology to spot next-day HRV patterns."
        }

        return "Connect Apple Health on Summary, import your Apple Health export.xml in Biology, log a meal in Fuel, or start a session in Train so I can synthesize live recovery, strain target, energy bank, and longevity protocols."
    }
}

// MARK: - Minimalist On-Device Intelligence Q&A Sheet
public struct ApexCoachSheet: View {
    @ObservedObject private var ai = ApexIntelligenceEngine.shared
    @ObservedObject private var health = HealthKitManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var draftQuestion: String = ""

    private let quickPrompts = [
        "Why did my readiness & energy change today?",
        "How should I hit my strain target today?",
        "Analyze my sleep debt & stages",
        "Review my Nutrition Quality, caffeine & glucose",
        "Summarize my Pace of Aging & bloodwork labs"
    ]

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(ai.appleIntelligenceAvailable ? ApexTheme.accentVolt : ApexTheme.standCyan)
                        .frame(width: 7, height: 7)
                    Text(ai.engineLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        if ai.messages.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Private On-Device Intelligence")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("Analyzes your HealthKit baselines, sleep stages, optical VBT fatigue, and scanned lab markers 100% locally.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)

                                ForEach(quickPrompts, id: \.self) { prompt in
                                    Button {
                                        Haptics.tap()
                                        Task { await ai.ask(prompt, health: health) }
                                    } label: {
                                        HStack {
                                            Text(prompt)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(.white)
                                            Spacer()
                                            Image(systemName: "arrow.up.right")
                                                .font(.system(size: 12))
                                                .foregroundStyle(ApexTheme.accentVolt)
                                        }
                                        .appleCard(padding: 14, cornerRadius: 16)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else {
                            ForEach(ai.messages) { msg in
                                HStack {
                                    if msg.isUser { Spacer(minLength: 40) }
                                    Text(msg.text)
                                        .font(.system(size: 15))
                                        .foregroundStyle(msg.isUser ? .black : .white)
                                        .padding(14)
                                        .background(msg.isUser ? ApexTheme.accentVolt : ApexTheme.cardSurface)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    if !msg.isUser { Spacer(minLength: 40) }
                                }
                            }
                        }

                        if ai.isThinking {
                            HStack(spacing: 8) {
                                ProgressView().tint(ApexTheme.accentVolt)
                                Text("Synthesizing biomarkers...")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(16)
                }

                Divider().background(Color.white.opacity(0.08))

                HStack(spacing: 10) {
                    TextField("Ask about HRV, sleep, lifts, or labs...", text: $draftQuestion)
                        .font(.system(size: 15))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(ApexTheme.cardSurface)
                        .clipShape(Capsule())

                    Button {
                        let q = draftQuestion
                        draftQuestion = ""
                        Haptics.tap(.medium)
                        Task { await ai.ask(q, health: health) }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(ApexTheme.accentVolt)
                    }
                    .disabled(draftQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ai.isThinking)
                }
                .padding(14)
            }
            .background(ApexTheme.background)
            .navigationTitle("APEX Intelligence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !ai.messages.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Clear", role: .destructive) {
                            Haptics.tap()
                            ai.clearMessages()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
