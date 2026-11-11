import SwiftUI
import Charts

public enum BevelDetailFocus: String, Identifiable {
    case recovery, strain, energyBank, stress, sleepCoach, healthMonitor
    public var id: String { rawValue }
}

// MARK: - Bevel Pro Trio, Intraday Stress, Energy Bank, Sleep Debt & 5-Vital Health Monitor Detail Sheet
public struct BevelScoresDetailSheet: View {
    public let focus: BevelDetailFocus
    @ObservedObject var health: HealthKitManager
    @Environment(\.dismiss) private var dismiss
    @State private var showBreathwork = false

    public init(focus: BevelDetailFocus, health: HealthKitManager) {
        self.focus = focus
        self.health = health
    }

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    energyBankSection
                    stressSection
                    healthMonitorSection
                    sleepCoachSection
                }
                .padding(16)
            }
            .background(ApexTheme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showBreathwork) {
                BreathworkHapticsView()
            }
        }
    }

    private var title: String {
        switch focus {
        case .recovery: return "Recovery Readiness"
        case .strain: return "Daily Strain & Target"
        case .energyBank: return "Energy Bank Trajectory"
        case .stress: return "Intraday Stress Monitor"
        case .sleepCoach: return "Sleep Needed & Debt"
        case .healthMonitor: return "Health Monitor (5 Vitals)"
        }
    }

    private var energyBankSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Energy Bank")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Morning Readiness drained by Stress & Strain, recharged by naps")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(health.energyBankPercent.map { "\($0)%" } ?? "—")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(ApexTheme.exerciseLime)
            }

            if health.energyBankCurve.count >= 2 {
                Chart {
                    ForEach(health.energyBankCurve) { pt in
                        AreaMark(x: .value("Hour", pt.date), y: .value("Battery", pt.value))
                            .foregroundStyle(LinearGradient(colors: [ApexTheme.exerciseLime.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Hour", pt.date), y: .value("Battery", pt.value))
                            .foregroundStyle(ApexTheme.exerciseLime)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }
                }
                .frame(height: 120)
                .chartYScale(domain: 0...100)
            } else {
                Text("Connect Apple Health overnight HRV/sleep to compute your live Energy Bank depletion curve.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Power Nap Recharge")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("+20m Nap (+Battery)") {
                    Haptics.tap()
                    health.loggedNapHoursToday += 0.33
                    health.persistWidgetSnapshot()
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(ApexTheme.standCyan)
                .clipShape(Capsule())
            }
        }
        .appleCard(padding: 16, cornerRadius: 20)
    }

    private var stressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Autonomic Stress Monitor")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Derived from today's Heart Rate Reserve vs 7d Resting HR & HRV")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(health.currentStressScore.map { "\($0)/100" } ?? "—")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle((health.currentStressScore ?? 0) > 65 ? ApexTheme.accentAmber : ApexTheme.standCyan)
            }

            if !health.stressHourlyCurve.isEmpty {
                Chart {
                    ForEach(health.stressHourlyCurve) { pt in
                        BarMark(x: .value("Hour", pt.label), y: .value("Stress", pt.value))
                            .foregroundStyle(pt.value > 70 ? ApexTheme.moveCrimson : pt.value > 45 ? ApexTheme.accentAmber : ApexTheme.standCyan)
                            .cornerRadius(4)
                    }
                }
                .frame(height: 110)
                .chartYScale(domain: 0...100)
            } else {
                Text("No intraday Apple Watch heart rate samples captured today yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Button {
                Haptics.tap(.medium)
                showBreathwork = true
            } label: {
                Label("Down-Regulate with Haptic Breathwork", systemImage: "wind")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(ApexTheme.standCyan)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .appleCard(padding: 16, cornerRadius: 20)
    }

    private var healthMonitorSection: some View {
        let summary = health.vitalRangeSummary
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Health Monitor")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                if summary.total > 0 {
                    Text("\(summary.inRange)/\(summary.total) Within Range")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(summary.inRange == summary.total ? ApexTheme.accentEmerald : ApexTheme.accentAmber)
                } else {
                    Text("Awaiting Sensors")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            if summary.items.isEmpty {
                Text("Wear Apple Watch overnight to monitor Resting HR, HRV, Respiratory Rate, Wrist Temp & SpO₂ deviations.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(summary.items, id: \.name) { row in
                    HStack {
                        Circle()
                            .fill(row.inRange ? ApexTheme.accentEmerald : ApexTheme.accentAmber)
                            .frame(width: 8, height: 8)
                        Text(row.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(row.value)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(row.note)
                                .font(.system(size: 10))
                                .foregroundStyle(row.inRange ? ApexTheme.accentEmerald : ApexTheme.accentAmber)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .appleCard(padding: 16, cornerRadius: 20)
    }

    private var sleepCoachSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Sleep Needed & Debt")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                if let needed = health.sleepNeededHours {
                    Text(String(format: "%.1fh Tonight", needed))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(ApexTheme.accentIndigo)
                }
            }

            HStack {
                Text("Baseline Target")
                Spacer()
                Stepper(String(format: "%.2fh", health.baselineSleepGoalHours), value: $health.baselineSleepGoalHours, in: 6.5...9.5, step: 0.25)
            }
            .font(.system(size: 13))
            .foregroundStyle(.white)

            if let debt = health.sleepDebtHours {
                Text(String(format: "Rolling 7-Day Sleep Debt: %.1fh (factors strain surcharge)", debt))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                Text("Record sleep nights in Apple Health to track cumulative Sleep Debt & bedtime targets.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .appleCard(padding: 16, cornerRadius: 20)
    }
}

// MARK: - Bevel Intelligence Morning Briefing & Evening Wrap-Up Sheet
public struct MorningEveningBriefingSheet: View {
    @ObservedObject var health: HealthKitManager
    @ObservedObject var nutrition = NutritionLogStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Int = Calendar.current.component(.hour, from: Date()) >= 17 ? 1 : 0

    public init(health: HealthKitManager) {
        self.health = health
    }

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Briefing Mode", selection: $mode) {
                        Text("Morning Briefing").tag(0)
                        Text("Evening Wrap-Up").tag(1)
                    }
                    .pickerStyle(.segmented)

                    if mode == 0 {
                        morningCard
                    } else {
                        eveningCard
                    }
                }
                .padding(16)
            }
            .background(ApexTheme.background)
            .navigationTitle("Bevel Intelligence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var morningCard: some View {
        let rdyText = health.readinessScore.map { "\($0)%" } ?? "Unrecorded"
        let bankText = health.energyBankPercent.map { "\($0)%" } ?? "—"
        let strainGoalText = health.targetStrainRange.map { String(format: "%.1f–%.1f", $0.lowerBound, $0.upperBound) } ?? "Connect Health"
        let sleepText = health.sleepTotalHours.map { String(format: "%.1fh slept (Deep %.1fh, REM %.1fh)", $0, health.sleepDeepHours, health.sleepRemHours) } ?? "No sleep stages synced"

        return VStack(alignment: .leading, spacing: 14) {
            Label("Morning Recovery Briefing", systemImage: "sun.max.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(ApexTheme.accentVolt)

            Text(health.readinessScore != nil
                 ? "Your autonomic system starts the day at \(rdyText) Recovery with an Energy Bank of \(bankText). \(sleepText)."
                 : "Connect Apple Health on Summary so your morning briefing synthesizes real sleep stages, HRV baselines, and daily Strain targets.")
                .font(.system(size: 14))
                .foregroundStyle(.white)

            Divider().background(Color.white.opacity(0.08))

            briefingRow("Target Daily Strain", strainGoalText, ApexTheme.moveCrimson)
            briefingRow("Vitals Status", health.vitalRangeSummary.total > 0 ? "\(health.vitalRangeSummary.inRange)/\(health.vitalRangeSummary.total) within range" : "No Sensors", ApexTheme.standCyan)
            briefingRow("Protein Target", "\(Int(nutrition.proteinTargetG))g today", ApexTheme.exerciseLime)
        }
        .appleCard(padding: 18, cornerRadius: 22)
    }

    private var eveningCard: some View {
        let strainText = health.todayStrainScore.map { String(format: "%.1f / 21", $0) } ?? "0.0"
        let nutScoreText = nutrition.nutritionQualityScore.map { "\($0) / 100" } ?? "No meals logged"
        let sleepNeededText = health.sleepNeededHours.map { String(format: "%.1fh needed tonight", $0) } ?? "Connect Sleep history"
        let journalCount = ExperimentLabStore.shared.dailyTagsToday.count

        return VStack(alignment: .leading, spacing: 14) {
            Label("Evening Day Wrap-Up", systemImage: "moon.stars.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(ApexTheme.accentIndigo)

            Text("Today you logged Strain \(strainText) (\(Int(health.moveCalories)) kcal moved) and Nutrition Quality \(nutScoreText). \(sleepNeededText).")
                .font(.system(size: 14))
                .foregroundStyle(.white)

            Divider().background(Color.white.opacity(0.08))

            briefingRow("Energy Bank Remaining", health.energyBankPercent.map { "\($0)%" } ?? "—", ApexTheme.exerciseLime)
            briefingRow("Current Stress Score", health.currentStressScore.map { "\($0) / 100" } ?? "—", ApexTheme.accentAmber)
            briefingRow("Journal Habits Logged", "\(journalCount) tag(s) today", ApexTheme.standCyan)
        }
        .appleCard(padding: 18, cornerRadius: 22)
    }

    private func briefingRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }
}
