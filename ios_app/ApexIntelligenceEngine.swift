import SwiftUI
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

public struct CoachMessage: Identifiable, Equatable {
    public let id = UUID()
    public let isUser: Bool
    public let text: String
    public let timestamp = Date()
}

// MARK: - Private On-Device Apple Intelligence Physician & Protocol Q&A Engine
@MainActor
public final class ApexIntelligenceEngine: ObservableObject {
    public static let shared = ApexIntelligenceEngine()

    @Published public var messages: [CoachMessage] = []
    @Published public var isThinking: Bool = false
    @Published public var engineLabel: String = "On-Device Protocol Engine"
    @Published public var appleIntelligenceAvailable: Bool = false

    private init() {
        refreshAvailability()
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
        isThinking = false
    }

    private func buildBiometricContext(health: HealthKitManager) -> String {
        let nutrition = NutritionLogStore.shared
        let tagsToday = ExperimentLabStore.shared.dailyTagsToday
        let monitor = health.vitalRangeSummary

        var lines: [String] = ["Current Telemetry:"]
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
            lines.append("- Body Fat: \(String(format: "%.1f%%", fat)), Lean Mass: \(health.leanBodyMassKg.map { String(format: "%.1f kg", $0) } ?? "n/a")")
        }
        if let glucose = health.glucoseSamples24h.last {
            lines.append("- Latest Glucose: \(Int(glucose.value.rounded())) mg/dL")
        }
        if let nScore = nutrition.nutritionQualityScore {
            lines.append("- Nutrition Quality Score: \(nScore)/100 (\(Int(nutrition.todayCalories.rounded())) kcal, \(Int(nutrition.todayProtein.rounded()))g P, Water \(Int(nutrition.waterMlToday.rounded()))mL, Caffeine \(Int(nutrition.caffeineMgToday.rounded()))mg)")
        }
        if !tagsToday.isEmpty {
            lines.append("- Daily Journal Tags Today: \(tagsToday.joined(separator: ", "))")
        }
        if let bio = health.biologicalAge {
            lines.append("- Fitness Biological Age: \(String(format: "%.1f", bio))y vs Chronological \(Int(health.chronologicalAge))y")
        }
        if let clinical = health.clinicalPhenoAge {
            lines.append("- Bloodwork Levine PhenoAge: \(String(format: "%.1f", clinical))y")
        }
        return lines.joined(separator: "\n")
    }

    private func synthesizeLocalClinicalReply(question: String, health: HealthKitManager) -> String {
        let lower = question.lowercased()
        let nutrition = NutritionLogStore.shared

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

        if lower.contains("energy") || lower.contains("stress") || lower.contains("battery") || lower.contains("strain") {
            let energyStr = health.energyBankPercent.map { "\($0)% Energy Bank" } ?? "Energy Bank pending HealthKit"
            let stressStr = health.currentStressScore.map { "\($0)/100 current stress" } ?? "Stress pending HR/HRV"
            let strainStr = health.todayStrainScore.map { String(format: "%.1f/21 Strain", $0) } ?? "Strain pending movement"
            return "Live Autonomic Balance: \(energyStr), \(stressStr), \(strainStr). \(health.energyBankPercent.map { $0 < 40 ? "Consider a 20m power nap or nasal Zone 2 decompression to recharge reserves." : "Metabolic reserve supports focused training or cognitive blocks." } ?? "Connect HealthKit on Summary for live Bevel curves.")"
        }

        if lower.contains("fuel") || lower.contains("nutri") || lower.contains("macro") || lower.contains("glucose") || lower.contains("cgm") || lower.contains("meal") {
            if let qScore = nutrition.nutritionQualityScore {
                let cgmStr = health.glucoseSamples24h.last.map { " Latest CGM glucose: \(Int($0.value.rounded())) mg/dL." } ?? ""
                return "Today's Nutrition Quality Score is \(qScore)/100 across \(Int(nutrition.todayCalories.rounded())) kcal and \(Int(nutrition.todayProtein.rounded()))g protein (\(Int(nutrition.waterMlToday.rounded())) mL water).\(cgmStr) Keep protein >=1.6g/kg and pair carbs with fiber."
            }
            return "No meals logged in Fuel today. Scan a barcode, snap a nutrition label, or describe a meal in the Fuel tab to compute your Nutrition Quality Score and CGM response."
        }

        if lower.contains("pheno") || lower.contains("lab") || lower.contains("blood") {
            if let clinical = health.clinicalPhenoAge {
                let diff = clinical - health.chronologicalAge
                return String(
                    format: "Your scanned Clinical PhenoAge is %.1f yrs (%+.1f vs chronological %d yrs). Prioritize hs-CRP below 0.8 mg/L, fasting glucose 75–85 mg/dL, and regular Zone 2 cardio to drive further epigenetic reversal.",
                    clinical, diff, Int(health.chronologicalAge)
                )
            }
            return "No bloodwork lab panel has been scanned yet. Open Biology -> Bloodwork Lab OCR to scan a PDF or paper slip for your exact clinical PhenoAge."
        }

        if lower.contains("train") || lower.contains("workout") || lower.contains("squat") || lower.contains("push") {
            if let delta = health.hrvDeltaPercent, delta <= -12 {
                return "HRV is \(delta)% below your 7-day baseline. Swap high-CNS maximal squats today for 35 minutes of nasal Zone 2 incline walking (128–140 bpm) or light mobility."
            }
            if let rdy = health.readinessScore, rdy >= 78 {
                let targetText = health.targetStrainRange.map { String(format: " Aim for %.0f–%.0f Daily Strain.", $0.lowerBound, $0.upperBound) } ?? ""
                return "Autonomic readiness is strong at \(rdy)%.\(targetText) Prime window for Strength Builder progression or Optical Train velocity sets."
            }
            return "Use Strength Builder or Optical Train today: warm up clean, log RPE accurately, and respect your target strain zone."
        }

        if let rdy = health.readinessScore {
            let hrvStr = health.heartRateVariability.map { "\(Int($0.rounded())) ms" } ?? "no HRV reading"
            let rhrStr = health.restingHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "no RHR reading"
            let extraEnergy = health.energyBankPercent.map { " Energy Bank is at \($0)%." } ?? ""
            return "Recovery Readiness is \(rdy)% (\(hrvStr) HRV, \(rhrStr) RHR).\(extraEnergy) Check your Daily Journal tags in Biology to spot next-day HRV patterns."
        }

        return "Connect Apple Health on Summary, log a meal in Fuel, or start a session in Train so I can synthesize live recovery, strain target, energy bank, and longevity protocols."
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
        "Review my Nutrition Quality & glucose"
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
