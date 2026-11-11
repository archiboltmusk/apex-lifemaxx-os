import SwiftUI
import Charts

public enum SelectedBiometricDetail: String, Identifiable {
    case restingHR, hrv, vo2Max, sleep
    public var id: String { rawValue }
}

// MARK: - Today Summary View (Apple Fitness & Vitals Aesthetic + 7-Day Swift Charts)
public struct SummaryView: View {
    @ObservedObject private var health = HealthKitManager.shared
    @Binding var selectedTab: Int

    @State private var detailMetric: SelectedBiometricDetail? = nil

    public init(selectedTab: Binding<Int>) {
        self._selectedTab = selectedTab
    }

    private var todayDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date()).uppercased()
    }

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text(todayDateLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, -6)

                    if health.connectionState == .needsPermission {
                        healthPermissionCard
                    }

                    activityHeroCard

                    vitalsSection

                    if hasOvernightExtras {
                        overnightSensorsCard
                    }

                    todaysFocusCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(ApexTheme.background)
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        if health.isAuthorized {
                            health.fetchLiveHealthMetrics()
                        } else {
                            health.requestAuthorization()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(health.isAuthorized ? ApexTheme.accentEmerald : ApexTheme.accentAmber)
                                .frame(width: 7, height: 7)
                            Text(health.isAuthorized ? "Live" : "Connect")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(ApexTheme.cardSurface)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder(ApexTheme.subtleBorder, lineWidth: 0.5)
                        )
                    }
                }
            }
            .refreshable {
                Haptics.tap()
                health.fetchLiveHealthMetrics()
            }
            .sheet(item: $detailMetric) { metric in
                BiometricDetailSheet(metric: metric, health: health)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Activity Rings Hero Card
    private var activityHeroCard: some View {
        VStack(spacing: 18) {
            HStack {
                HStack(spacing: 6) {
                    Text("Activity")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    if health.hasExactWatchSummary {
                        Text("WATCH")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(ApexTheme.standCyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ApexTheme.standCyan.opacity(0.14))
                            .clipShape(Capsule())
                    }
                }
                Spacer()
                Text(health.statusLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(health.isAuthorized ? ApexTheme.accentEmerald : .secondary)
            }

            HStack(spacing: 24) {
                ActivityRingsView(
                    moveCurrent: health.moveCalories,
                    moveTarget: health.moveTarget,
                    exerciseCurrent: health.exerciseMinutes,
                    exerciseTarget: health.exerciseTarget,
                    standCurrent: health.standHours,
                    standTarget: health.standTarget,
                    size: 136
                )

                VStack(alignment: .leading, spacing: 14) {
                    ringStatRow(
                        label: "Move",
                        value: "\(Int(health.moveCalories))",
                        target: "/\(Int(health.moveTarget)) kcal",
                        color: ApexTheme.moveCrimson
                    )
                    ringStatRow(
                        label: "Exercise",
                        value: "\(Int(health.exerciseMinutes))",
                        target: "/\(Int(health.exerciseTarget)) min",
                        color: ApexTheme.exerciseLime
                    )
                    ringStatRow(
                        label: "Stand",
                        value: "\(Int(health.standHours))",
                        target: "/\(Int(health.standTarget)) hr",
                        color: ApexTheme.standCyan
                    )
                }
                Spacer(minLength: 0)
            }

            Divider().background(Color.white.opacity(0.08))

            HStack {
                Label("\(health.dailySteps.formatted()) steps", systemImage: "figure.walk")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Haptics.tap()
                    selectedTab = 2
                } label: {
                    Text("Start Workout")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ApexTheme.moveCrimson)
                }
            }
        }
        .appleCard(padding: 18, cornerRadius: 24)
    }

    private func ringStatRow(label: String, value: String, target: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                Text(target)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Vitals 2x2 Grid with Personal 7d Baselines
    private var vitalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Vitals")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                if let readiness = health.readinessScore {
                    Text("Readiness \(readiness)%")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(readiness >= 75 ? ApexTheme.accentEmerald : ApexTheme.accentAmber)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background((readiness >= 75 ? ApexTheme.accentEmerald : ApexTheme.accentAmber).opacity(0.14))
                        .clipShape(Capsule())
                }
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                AppleBiometricTile(
                    title: "Resting HR",
                    value: health.restingHeartRate.map { "\(Int($0.rounded()))" } ?? "—",
                    unit: health.restingHeartRate != nil ? "bpm" : "",
                    detail: rhrAssessment,
                    tint: ApexTheme.moveCrimson,
                    systemIcon: "heart.fill"
                ) {
                    detailMetric = .restingHR
                }

                AppleBiometricTile(
                    title: "HRV",
                    value: health.heartRateVariability.map { "\(Int($0.rounded()))" } ?? "—",
                    unit: health.heartRateVariability != nil ? "ms" : "",
                    detail: hrvAssessment,
                    tint: ApexTheme.standCyan,
                    systemIcon: "waveform.path.ecg"
                ) {
                    detailMetric = .hrv
                }

                AppleBiometricTile(
                    title: "Cardio Fitness",
                    value: health.vo2Max.map { String(format: "%.1f", $0) } ?? "—",
                    unit: health.vo2Max != nil ? "VO₂" : "",
                    detail: health.vo2Max.map { $0 >= 48 ? "Optimal Ceiling" : "Steady Baseline" } ?? "No Sample",
                    tint: ApexTheme.exerciseLime,
                    systemIcon: "flame.fill"
                ) {
                    detailMetric = .vo2Max
                }

                AppleBiometricTile(
                    title: "Sleep",
                    value: formattedSleepValue,
                    unit: "",
                    detail: sleepAssessment,
                    tint: ApexTheme.accentIndigo,
                    systemIcon: "bed.double.fill"
                ) {
                    detailMetric = .sleep
                }
            }
        }
    }

    // MARK: - Overnight Sensors & Sleep Stages Pill Strip (Shown when Health samples exist)
    private var hasOvernightExtras: Bool {
        health.bloodOxygenPercent != nil || health.respiratoryRateBpm != nil || health.wristTempDeltaC != nil || (health.sleepDeepHours + health.sleepRemHours) > 0
    }

    private var overnightSensorsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Overnight Physiology")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                if let eff = health.sleepEfficiencyPercent {
                    Text("\(eff)% Efficiency")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(ApexTheme.accentIndigo)
                }
            }

            if (health.sleepDeepHours + health.sleepRemHours + health.sleepCoreHours) > 0 {
                SleepStagesBar(
                    deep: health.sleepDeepHours,
                    rem: health.sleepRemHours,
                    core: health.sleepCoreHours,
                    awake: health.sleepAwakeHours
                )
            }

            HStack(spacing: 10) {
                if let spo2 = health.bloodOxygenPercent {
                    overnightSensorPill(label: "Blood O₂", value: "\(Int(spo2))%", color: ApexTheme.standCyan)
                }
                if let resp = health.respiratoryRateBpm {
                    overnightSensorPill(label: "Resp Rate", value: String(format: "%.1f/m", resp), color: ApexTheme.accentEmerald)
                }
                if let temp = health.wristTempDeltaC {
                    let sign = temp >= 0 ? "+" : ""
                    overnightSensorPill(label: "Wrist Temp", value: String(format: "%@%.2f°", sign, temp), color: ApexTheme.accentAmber)
                }
            }
        }
        .appleCard(padding: 16, cornerRadius: 20)
    }

    private func overnightSensorPill(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ApexTheme.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Clean Apple Health Permission Card
    private var healthPermissionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 34, height: 34)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(ApexTheme.moveCrimson)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Health Sync")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Stream heart rate, HRV, sleep stages, and Watch rings")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                Haptics.tap(.medium)
                health.requestAuthorization()
            } label: {
                Text("Connect Apple Health")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ApexTheme.accentVolt)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .appleCard(padding: 16, cornerRadius: 20)
    }

    // MARK: - Adaptive Context-Aware Focus Card
    private var todaysFocusCard: some View {
        let coach = adaptiveRecommendation

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TODAY'S FOCUS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ApexTheme.accentVolt)
                Spacer()
                Image(systemName: coach.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(ApexTheme.accentVolt)
            }

            Text(coach.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Text(coach.detail)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Haptics.tap()
                selectedTab = coach.targetTab
            } label: {
                HStack {
                    Text(coach.ctaTitle)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(ApexTheme.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .appleCard(padding: 18, cornerRadius: 22)
    }

    private var adaptiveRecommendation: (title: String, detail: String, ctaTitle: String, targetTab: Int, icon: String) {
        if let delta = health.hrvDeltaPercent, delta <= -15 {
            return (
                "Recovery Priority · HRV \(delta)%",
                "Autonomic readiness is suppressed below your 7-day baseline. Favor nasal Zone 2 walking, mobility, and earlier bedtime today.",
                "Review Longevity & Sleep",
                3,
                "waveform.path.ecg"
            )
        }
        if let readiness = health.readinessScore, readiness >= 82 {
            return (
                "Prime for Progressive Overload",
                "Readiness at \(readiness)% with restored HRV. High neural drive available for squats, pull-ups, or velocity sets.",
                "Start Optical Training",
                2,
                "bolt.fill"
            )
        }
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return (
                "Morning Symmetry & Baseline Check",
                "Capture an aligned morning craniofacial scan before lunch to track water retention and midline balance consistently.",
                "Open Face Scan",
                1,
                "faceid"
            )
        } else if hour < 18 {
            return (
                "Peak Strength Window",
                "Core body temperature rises toward afternoon peak. Ideal window for optical form tracking and progressive sets.",
                "Start Optical Training",
                2,
                "figure.strengthtraining.traditional"
            )
        } else {
            return (
                "Evening Decompression & Circadian Prep",
                "Review your caffeine cutoff, clinical PhenoAge, and Dead Hang endurance before winding down.",
                "View Longevity",
                3,
                "moon.stars.fill"
            )
        }
    }

    private var rhrAssessment: String {
        guard health.restingHeartRate != nil else { return "No Sample" }
        if let diff = health.rhrDeltaBpm {
            if diff == 0 { return "On 7d Baseline" }
            return diff < 0 ? "\(diff) bpm vs 7d" : "+\(diff) bpm vs 7d"
        }
        return "Apple Watch"
    }

    private var hrvAssessment: String {
        guard let hrv = health.heartRateVariability else { return "No Sample" }
        if let pct = health.hrvDeltaPercent {
            return pct >= 0 ? "+\(pct)% vs 7d" : "\(pct)% vs 7d"
        }
        return hrv >= 70 ? "High Recovery" : hrv >= 45 ? "Balanced" : "Rest Needed"
    }

    private var sleepAssessment: String {
        guard health.sleepTotalHours != nil else { return "No Sample" }
        if (health.sleepDeepHours + health.sleepRemHours) > 0.1 {
            return String(format: "%.1fh Deep · %.1fh REM", health.sleepDeepHours, health.sleepRemHours)
        }
        return "Sleep Architecture"
    }

    private var formattedSleepValue: String {
        guard let hours = health.sleepTotalHours, hours > 0 else { return "—" }
        let wholeHours = Int(hours)
        let mins = Int(((hours - Double(wholeHours)) * 60).rounded())
        return "\(wholeHours)h \(mins)m"
    }
}

// MARK: - Apple Health 4-Stage Sleep Distribution Bar
private struct SleepStagesBar: View {
    let deep: Double
    let rem: Double
    let core: Double
    let awake: Double

    var body: some View {
        let total = max(0.01, deep + rem + core + awake)
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    if deep > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ApexTheme.accentIndigo)
                            .frame(width: geo.size.width * CGFloat(deep / total))
                    }
                    if rem > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ApexTheme.standCyan)
                            .frame(width: geo.size.width * CGFloat(rem / total))
                    }
                    if core > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue.opacity(0.65))
                            .frame(width: geo.size.width * CGFloat(core / total))
                    }
                    if awake > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ApexTheme.accentAmber.opacity(0.8))
                            .frame(width: geo.size.width * CGFloat(awake / total))
                    }
                }
            }
            .frame(height: 10)

            HStack(spacing: 12) {
                legendItem("Deep", deep, ApexTheme.accentIndigo)
                legendItem("REM", rem, ApexTheme.standCyan)
                legendItem("Core", core, Color.blue.opacity(0.8))
                if awake > 0.05 {
                    legendItem("Awake", awake, ApexTheme.accentAmber)
                }
            }
        }
    }

    private func legendItem(_ name: String, _ hours: Double, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(name) \(String(format: "%.1fh", hours))")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Native Apple Biometric Metric Sheet with Swift Charts 7-Day Trend
private struct BiometricDetailSheet: View {
    let metric: SelectedBiometricDetail
    @ObservedObject var health: HealthKitManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(headline)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(explanation)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Reading")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text(currentReading)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Longevity Optimal")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text(optimalRange)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(ApexTheme.accentEmerald)
                        }
                    }
                    .appleCard(padding: 16, cornerRadius: 18)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("7-Day Personal Trend")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            if let avg = rollingAverage {
                                Text("7d Avg \(avg)")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(tintColor)
                            }
                        }

                        if trendSeries.count >= 2 {
                            Chart {
                                ForEach(trendSeries) { point in
                                    AreaMark(
                                        x: .value("Day", point.date, unit: .day),
                                        y: .value("Value", point.value)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [tintColor.opacity(0.32), tintColor.opacity(0.0)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )

                                    LineMark(
                                        x: .value("Day", point.date, unit: .day),
                                        y: .value("Value", point.value)
                                    )
                                    .foregroundStyle(tintColor)
                                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                                    PointMark(
                                        x: .value("Day", point.date, unit: .day),
                                        y: .value("Value", point.value)
                                    )
                                    .foregroundStyle(tintColor)
                                }

                                if let baseVal = baselineNumeric {
                                    RuleMark(y: .value("Baseline", baseVal))
                                        .foregroundStyle(Color.white.opacity(0.3))
                                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                }
                            }
                            .frame(height: 170)
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day)) {
                                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                                        .foregroundStyle(Color.secondary)
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading) {
                                    AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                                    AxisValueLabel().foregroundStyle(Color.secondary)
                                }
                            }
                        } else {
                            HStack(spacing: 10) {
                                Image(systemName: "chart.xyaxis.line")
                                    .foregroundStyle(.secondary)
                                Text("Record at least 2 days in Apple Health to plot your rolling 7-day curve.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 18)
                        }
                    }
                    .appleCard(padding: 16, cornerRadius: 18)
                }
                .padding(20)
            }
            .background(ApexTheme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var trendSeries: [DailyMetricPoint] {
        switch metric {
        case .restingHR: return health.rhrHistory
        case .hrv: return health.hrvHistory
        case .vo2Max: return health.vo2History
        case .sleep: return health.sleepHistory
        }
    }

    private var tintColor: Color {
        switch metric {
        case .restingHR: return ApexTheme.moveCrimson
        case .hrv: return ApexTheme.standCyan
        case .vo2Max: return ApexTheme.exerciseLime
        case .sleep: return ApexTheme.accentIndigo
        }
    }

    private var baselineNumeric: Double? {
        guard !trendSeries.isEmpty else { return nil }
        return trendSeries.reduce(0) { $0 + $1.value } / Double(trendSeries.count)
    }

    private var rollingAverage: String? {
        guard let val = baselineNumeric else { return nil }
        switch metric {
        case .restingHR: return "\(Int(val.rounded())) bpm"
        case .hrv: return "\(Int(val.rounded())) ms"
        case .vo2Max: return String(format: "%.1f", val)
        case .sleep: return String(format: "%.1fh", val)
        }
    }

    private var title: String {
        switch metric {
        case .restingHR: return "Resting Heart Rate"
        case .hrv: return "Heart Rate Variability"
        case .vo2Max: return "Cardio Fitness"
        case .sleep: return "Sleep Duration"
        }
    }

    private var headline: String {
        switch metric {
        case .restingHR: return "Cardiac Efficiency"
        case .hrv: return "Autonomic Nervous System"
        case .vo2Max: return "Aerobic Ceiling"
        case .sleep: return "Nocturnal Recovery"
        }
    }

    private var currentReading: String {
        switch metric {
        case .restingHR: return health.restingHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "No Data"
        case .hrv: return health.heartRateVariability.map { "\(Int($0.rounded())) ms" } ?? "No Data"
        case .vo2Max: return health.vo2Max.map { String(format: "%.1f mL/kg·min", $0) } ?? "No Data"
        case .sleep: return health.sleepTotalHours.map { String(format: "%.1f hours", $0) } ?? "No Data"
        }
    }

    private var optimalRange: String {
        switch metric {
        case .restingHR: return "45 – 56 bpm"
        case .hrv: return "> 70 ms"
        case .vo2Max: return "> 50 mL/kg·min"
        case .sleep: return "7.5 – 8.5 hrs"
        }
    }

    private var explanation: String {
        switch metric {
        case .restingHR:
            return "Measured passively during deep rest and overnight sleep. Deviations above baseline signal accumulated fatigue or illness."
        case .hrv:
            return "SDNN beat-to-beat variation reflects vagus nerve readiness compared directly against your personal 7-day rolling baseline."
        case .vo2Max:
            return "Maximal oxygen uptake is the strongest clinical predictor of cardiovascular lifespan and longevity."
        case .sleep:
            return "Total restorative sleep broken into Deep, REM, and Core stages. Deep sleep repairs muscle; REM consolidates motor learning."
        }
    }
}
