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
                    orderedSections
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

    @ViewBuilder
    private var orderedSections: some View {
        switch focus {
        case .recovery:
            recoverySection
            healthMonitorSection
            sleepCoachSection
            energyBankSection
            stressSection
        case .strain:
            strainSection
            energyBankSection
            recoverySection
            stressSection
        case .energyBank:
            energyBankSection
            strainSection
            stressSection
            sleepCoachSection
        case .stress:
            stressSection
            energyBankSection
            healthMonitorSection
        case .healthMonitor:
            healthMonitorSection
            recoverySection
            sleepCoachSection
        case .sleepCoach:
            sleepCoachSection
            recoverySection
            energyBankSection
            healthMonitorSection
        }
    }

    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Autonomic Recovery Contributors")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Weighted from 7d HRV deviation, RHR delta & nocturnal sleep")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(health.readinessScore.map { "\($0)%" } ?? "—")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(ApexTheme.accentEmerald)
            }

            HStack(spacing: 10) {
                contributorPill(
                    label: "HRV SDNN",
                    value: health.heartRateVariability.map { "\(Int($0.rounded())) ms" } ?? "—",
                    sub: health.hrvDeltaPercent.map { String(format: "%+d%% vs 7d", $0) } ?? "Need 2d base",
                    tint: ApexTheme.standCyan
                )
                contributorPill(
                    label: "Resting HR",
                    value: health.restingHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "—",
                    sub: health.rhrDeltaBpm.map { String(format: "%+d vs 7d", $0) } ?? "Need 2d base",
                    tint: ApexTheme.moveCrimson
                )
                contributorPill(
                    label: "Sleep Eff.",
                    value: health.sleepEfficiencyPercent.map { "\($0)%" } ?? "—",
                    sub: health.sleepTotalHours.map { String(format: "%.1fh total", $0) } ?? "—",
                    tint: ApexTheme.accentIndigo
                )
            }
        }
        .appleCard(padding: 16, cornerRadius: 20)
    }

    private var strainSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cardiovascular & Muscular Strain")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    if let band = health.targetStrainRange {
                        Text(String(format: "Readiness-guided target zone: %.0f – %.0f", band.lowerBound, band.upperBound))
                            .font(.system(size: 12))
                            .foregroundStyle(ApexTheme.exerciseLime)
                    } else {
                        Text("Log workouts or connect Apple Health to track 0–21 strain load")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(health.todayStrainScore.map { String(format: "%.1f", $0) } ?? "0.0")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(ApexTheme.moveCrimson)
            }

            HStack(spacing: 10) {
                contributorPill(label: "Move", value: "\(Int(health.moveCalories)) kcal", sub: "Goal \(Int(health.moveTarget))", tint: ApexTheme.moveCrimson)
                contributorPill(label: "Exercise", value: "\(Int(health.exerciseMinutes)) min", sub: "Goal \(Int(health.exerciseTarget))m", tint: ApexTheme.exerciseLime)
                contributorPill(label: "Strength Bonus", value: String(format: "+%.1f", health.strengthStrainBonusToday), sub: "Resets daily", tint: ApexTheme.accentAmber)
            }
        }
        .appleCard(padding: 16, cornerRadius: 20)
    }

    private func contributorPill(label: String, value: String, sub: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
            Text(sub)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(ApexTheme.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                    health.addNapMinutes(20)
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

// MARK: - Whoop-Style Weekly Performance Assessment (WPA) Sheet
public struct WeeklyPerformanceSheet: View {
    @ObservedObject var health: HealthKitManager
    @Environment(\.dismiss) private var dismiss

    public init(health: HealthKitManager) {
        self.health = health
    }

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if let report = health.weeklyPerformanceReport {
                        heroSummaryCard(report)
                        sleepPerformanceSection(report)
                        strainRecoverySection(report)
                        habitsImpactSection(report)
                        vitalTrendsSection(report)
                    } else {
                        emptyStateCard
                    }
                }
                .padding(16)
            }
            .background(ApexTheme.background)
            .navigationTitle("Weekly Assessment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func heroSummaryCard(_ report: WeeklyPerformanceReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Weekly Performance Assessment", systemImage: "chart.bar.doc.horizontal.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(ApexTheme.accentVolt)

            Text("7-Day Autonomic Recovery, Sleep Quality & Training Workload Synthesis.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Divider().background(Color.white.opacity(0.08))

            HStack(spacing: 12) {
                metricMiniTile(
                    label: "Sleep Perf",
                    val: "\(report.sleepPerformancePct)%",
                    color: report.sleepPerformancePct >= 85 ? ApexTheme.accentEmerald : ApexTheme.accentAmber
                )
                metricMiniTile(
                    label: "Consistency",
                    val: "\(report.sleepConsistencyPct)%",
                    color: ApexTheme.accentIndigo
                )
                metricMiniTile(
                    label: "Target Days",
                    val: "\(report.optimalStrainDays)/7d",
                    color: ApexTheme.exerciseLime
                )
                metricMiniTile(
                    label: "ACWR Load",
                    val: String(format: "%.2f", report.acwrAverage),
                    color: ApexTheme.standCyan
                )
            }
        }
        .appleCard(padding: 16, cornerRadius: 20)
    }

    private func metricMiniTile(label: String, val: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(val)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(ApexTheme.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func sleepPerformanceSection(_ report: WeeklyPerformanceReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Sleep Quality & Regularity", systemImage: "bed.double.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(report.sleepPerformancePct)% Need Met")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(report.sleepPerformancePct >= 85 ? ApexTheme.accentEmerald : ApexTheme.accentAmber)
            }

            Text("Your 7-day sleep consistency score is \(report.sleepConsistencyPct)%. Consistent circadian bedtimes stabilize REM & Slow Wave Sleep.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            ProgressView(value: Double(report.sleepPerformancePct), total: 100.0)
                .tint(report.sleepPerformancePct >= 85 ? ApexTheme.accentEmerald : ApexTheme.accentAmber)
        }
        .appleCard(padding: 16, cornerRadius: 20)
    }

    private func strainRecoverySection(_ report: WeeklyPerformanceReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Strain vs. Recovery Alignment", systemImage: "bolt.heart.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            Text(report.strainRecoveryAlignment)
                .font(.system(size: 13))
                .foregroundStyle(.white)

            HStack {
                Text("Total Movement Burn")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(report.totalMoveKcal)) kcal")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(ApexTheme.moveCrimson)
            }
        }
        .appleCard(padding: 16, cornerRadius: 20)
    }

    private func habitsImpactSection(_ report: WeeklyPerformanceReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Habit Impact Leaderboard", systemImage: "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ApexTheme.accentVolt)

            if let pos = report.topPositiveHabit {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(ApexTheme.accentEmerald)
                    Text(pos)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("Top Positive")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ApexTheme.accentEmerald)
                }
            }

            if let neg = report.topNegativeHabit {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(ApexTheme.moveCrimson)
                    Text(neg)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("Avoid")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ApexTheme.moveCrimson)
                }
            }
        }
        .appleCard(padding: 16, cornerRadius: 20)
    }

    private func vitalTrendsSection(_ report: WeeklyPerformanceReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("7-Day Baselines")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            HStack {
                Text("Average HRV")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(report.avgHrv.map { "\(Int($0.rounded())) ms" } ?? "—")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(ApexTheme.standCyan)
            }

            HStack {
                Text("Average Resting HR")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(report.avgRhr.map { "\(Int($0.rounded())) bpm" } ?? "—")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(ApexTheme.moveCrimson)
            }
        }
        .appleCard(padding: 16, cornerRadius: 20)
    }

    private var emptyStateCard: some View {
        VStack(alignment: .center, spacing: 14) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Connect Apple Health or log workouts to compile your Weekly Performance Assessment.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .appleCard(padding: 24, cornerRadius: 20)
    }
}

// MARK: - Athlytic-Style ACWR Training Load & Injury Hazard Sheet
public struct ACWRTrainingLoadDetailSheet: View {
    @ObservedObject var health: HealthKitManager
    @Environment(\.dismiss) private var dismiss

    public init(health: HealthKitManager) {
        self.health = health
    }

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if let res = health.acwrResult {
                        gaugeCard(res)
                        zonesLegendCard
                        breakdownCard(res)
                    } else {
                        emptyStateCard
                    }
                }
                .padding(16)
            }
            .background(ApexTheme.background)
            .navigationTitle("Training Load & ACWR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func gaugeCard(_ res: ACWRResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Acute-to-Chronic Workload Ratio")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text("7-Day Acute Strain ÷ 28-Day Chronic Baseline")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(String(format: "%.2f", res.ratio))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(zoneColor(res.zone))
            }

            HStack {
                Text(res.zone.rawValue)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(zoneColor(res.zone))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(zoneColor(res.zone).opacity(0.18))
                    .clipShape(Capsule())
                Spacer()
            }

            Text(res.recommendation)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.9))
                .lineSpacing(3)
        }
        .appleCard(padding: 18, cornerRadius: 22)
    }

    private var zonesLegendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workload Zones (Gabbett 2016 Model)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)

            zoneRow("Under-training (< 0.80)", "Low acute stimulus; fitness may decay.", ApexTheme.standCyan)
            Divider().background(Color.white.opacity(0.06))
            zoneRow("Optimal Sweet Spot (0.80 – 1.30)", "Progressive fitness adaptations with lowest injury hazard.", ApexTheme.accentEmerald)
            Divider().background(Color.white.opacity(0.06))
            zoneRow("Overreaching (1.31 – 1.50)", "High fatigue accumulation; requires recovery buffer.", ApexTheme.accentAmber)
            Divider().background(Color.white.opacity(0.06))
            zoneRow("High Injury Risk (> 1.50)", "Acute strain spike; significantly elevated risk.", ApexTheme.moveCrimson)
        }
        .appleCard(padding: 16, cornerRadius: 20)
    }

    private func zoneRow(_ title: String, _ desc: String, _ color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func breakdownCard(_ res: ACWRResult) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Acute Load (7d)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f", res.acuteLoad7d))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(ApexTheme.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("Chronic Load (28d)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f", res.chronicLoad28d))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(ApexTheme.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func zoneColor(_ zone: TrainingZone) -> Color {
        switch zone {
        case .underTraining: return ApexTheme.standCyan
        case .optimal: return ApexTheme.accentEmerald
        case .overreaching: return ApexTheme.accentAmber
        case .injuryRisk: return ApexTheme.moveCrimson
        }
    }

    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "gauge.with.needle")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
            Text("Log workouts or connect Apple Health to compute your Acute-to-Chronic Workload Ratio.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .appleCard(padding: 20, cornerRadius: 20)
    }
}

// MARK: - Oura-Style Circadian Alignment & Chronotype Sheet
public struct CircadianChronotypeDetailSheet: View {
    @ObservedObject var health: HealthKitManager
    @Environment(\.dismiss) private var dismiss

    public init(health: HealthKitManager) {
        self.health = health
    }

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if let prof = health.circadianProfile {
                        chronotypeHeroCard(prof)
                        circadianScheduleCard(prof)
                        circadianScienceCard
                    } else {
                        emptyStateCard
                    }
                }
                .padding(16)
            }
            .background(ApexTheme.background)
            .navigationTitle("Circadian Alignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func chronotypeHeroCard(_ prof: CircadianProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Chronotype Classification", systemImage: "sun.haze.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(ApexTheme.accentVolt)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(prof.chronotype.rawValue)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Sleep Midpoint: \(prof.sleepMidpointFormatted)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(prof.regularityScore)% Regular")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ApexTheme.accentEmerald)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(ApexTheme.accentEmerald.opacity(0.18), in: Capsule())
            }
        }
        .appleCard(padding: 18, cornerRadius: 22)
    }

    private func circadianScheduleCard(_ prof: CircadianProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Optimal Circadian Timing Window")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            circadianRow("Melatonin Window Begins", prof.melatoninWindowStartFormatted, "moon.stars", ApexTheme.accentIndigo)
            Divider().background(Color.white.opacity(0.06))
            circadianRow("Optimal Bedtime Target", prof.optimalBedtimeFormatted, "bed.double.fill", ApexTheme.accentVolt)
            Divider().background(Color.white.opacity(0.06))
            circadianRow("Natural Awakening Target", prof.optimalWakeFormatted, "sun.horizon.fill", ApexTheme.accentAmber)
            Divider().background(Color.white.opacity(0.06))
            circadianRow("Cortisol Peak & Morning Light", prof.cortisolAwakeningFormatted, "sunrise.fill", ApexTheme.standCyan)
        }
        .appleCard(padding: 16, cornerRadius: 20)
    }

    private func circadianRow(_ label: String, _ time: String, _ icon: String, _ color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 22)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Text(time)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var circadianScienceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Why Circadian Regularity Matters")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            Text("Keeping bedtime within 30 minutes of your chronotype window maximizes Slow-Wave Sleep (growth hormone release) and stabilizes morning cortisol awakening response.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
        }
        .appleCard(padding: 16, cornerRadius: 20)
    }

    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
            Text("Record sleep in Apple Health to determine your biological chronotype and optimal sleep window.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .appleCard(padding: 20, cornerRadius: 20)
    }
}

// MARK: - Oura & Blueprint Cardiovascular Age & Arterial Compliance Detail Sheet
public struct CardiovascularAgeDetailSheet: View {
    @ObservedObject var health: HealthKitManager
    @Environment(\.dismiss) private var dismiss

    public init(health: HealthKitManager) {
        self.health = health
    }

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if let res = health.cardiovascularAgeResult {
                        heroCard(res)
                        biomarkersBreakdown(res)
                        recommendationCard(res)
                    } else {
                        emptyStateCard
                    }
                }
                .padding(16)
            }
            .background(ApexTheme.background)
            .navigationTitle("Cardiovascular Age")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func heroCard(_ res: CardiovascularAgeResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Vascular Elasticity & Capacity", systemImage: "heart.text.square.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(ApexTheme.moveCrimson)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.1f yrs", res.cardiovascularAge))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(res.ageDelta <= 0
                         ? String(format: "%.1f years younger than chronological age (%d)", abs(res.ageDelta), Int(res.chronologicalAge))
                         : String(format: "%.1f years above chronological baseline (%d)", res.ageDelta, Int(res.chronologicalAge)))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(res.ageDelta <= 0 ? ApexTheme.accentEmerald : ApexTheme.accentAmber)
                }
                Spacer()
                Text("Top \(100 - res.vo2MaxPercentile)%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ApexTheme.standCyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(ApexTheme.standCyan.opacity(0.16), in: Capsule())
            }

            Text(res.elasticityStatus)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ApexTheme.accentVolt)
        }
        .appleCard(padding: 18, cornerRadius: 22)
    }

    private func biomarkersBreakdown(_ res: CardiovascularAgeResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Vascular Contributors")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            contributorRow("Cardio Capacity (VO2 Max)", health.vo2Max.map { String(format: "%.1f ml/kg/min", $0) } ?? "Needs Watch Workout", ApexTheme.exerciseLime)
            Divider().background(Color.white.opacity(0.06))
            contributorRow("Resting Heart Rate", health.restingHeartRate.map { "\(Int($0)) bpm" } ?? "Needs Vitals", ApexTheme.moveCrimson)
            Divider().background(Color.white.opacity(0.06))
            contributorRow("Overnight HRV Elasticity", health.heartRateVariability.map { "\(Int($0)) ms" } ?? "Needs Sleep Vitals", ApexTheme.standCyan)
        }
        .appleCard(padding: 16, cornerRadius: 20)
    }

    private func contributorRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }

    private func recommendationCard(_ res: CardiovascularAgeResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vascular Longevity Protocol")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            Text(res.recommendation)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.9))
                .lineSpacing(3)
        }
        .appleCard(padding: 16, cornerRadius: 20)
    }

    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.circle")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
            Text("Connect Apple Health or record a workout to estimate your Cardiovascular Age.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .appleCard(padding: 20, cornerRadius: 20)
    }
}
