import SwiftUI

public enum SelectedBiometricDetail: String, Identifiable {
    case restingHR, hrv, vo2Max, sleep
    public var id: String { rawValue }
}

// MARK: - Today Summary View (Apple Fitness & Health Aesthetic)
public struct SummaryView: View {
    @ObservedObject private var health = HealthKitManager.shared
    @Binding var selectedTab: Int

    @State private var detailMetric: SelectedBiometricDetail? = nil
    @State private var showHealthHelpAlert: Bool = false

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
                    // Clean iOS Fitness-style Date Subheader
                    Text(todayDateLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, -6)

                    // 1. HEALTHKIT PERMISSION CALLOUT (Hidden once authorized)
                    if health.connectionState == .needsPermission {
                        healthPermissionCard
                    }

                    // 2. ACTIVITY RINGS HERO CARD
                    activityHeroCard

                    // 3. TRENDS & BIOMETRICS GRID
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Vitals")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                            if let readiness = health.readinessScore {
                                Text("Readiness \(readiness)%")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(ApexTheme.accentEmerald)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(ApexTheme.accentEmerald.opacity(0.14))
                                    .clipShape(Capsule())
                            }
                        }

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            AppleBiometricTile(
                                title: "Resting HR",
                                value: health.restingHeartRate.map { "\(Int($0.rounded()))" } ?? "—",
                                unit: health.restingHeartRate != nil ? "bpm" : "",
                                detail: health.restingHeartRate != nil ? "Apple Watch" : "No Sample",
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
                                detail: health.vo2Max != nil ? "Above Average" : "No Sample",
                                tint: ApexTheme.exerciseLime,
                                systemIcon: "flame.fill"
                            ) {
                                detailMetric = .vo2Max
                            }

                            AppleBiometricTile(
                                title: "Sleep",
                                value: formattedSleepValue,
                                unit: "",
                                detail: health.sleepTotalHours != nil ? "Sleep Architecture" : "No Sample",
                                tint: ApexTheme.accentIndigo,
                                systemIcon: "bed.double.fill"
                            ) {
                                detailMetric = .sleep
                            }
                        }
                    }

                    // 4. TODAY'S FOCUS GUIDANCE
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
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Activity Rings Hero Card
    private var activityHeroCard: some View {
        VStack(spacing: 18) {
            HStack {
                Text("Activity")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
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
                    selectedTab = 2 // Jump to Train tab
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
                    Text("Stream heart rate, HRV, sleep, and activity rings")
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

    // MARK: - Editorial Proactive Focus Card
    private var todaysFocusCard: some View {
        let hour = Calendar.current.component(.hour, from: Date())
        let title: String
        let detail: String
        let ctaTitle: String
        let targetTab: Int

        if hour < 12 {
            title = "Morning Readiness Check"
            detail = "Run a quick craniofacial symmetry scan or establish baseline Zone 2 aerobic output."
            ctaTitle = "Open Face Scan"
            targetTab = 1
        } else if hour < 18 {
            title = "Peak Strength Window"
            detail = "Core body temperature approaches circadian peak in the afternoon. Ideal time for squats or push-ups."
            ctaTitle = "Start Optical Training"
            targetTab = 2
        } else {
            title = "Evening Recovery & Sleep Prep"
            detail = "Review your circadian bedtime window and dead hang benchmark before winding down."
            ctaTitle = "View Longevity"
            targetTab = 3
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TODAY'S FOCUS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ApexTheme.accentVolt)
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 13))
                    .foregroundStyle(ApexTheme.accentVolt)
            }

            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Text(detail)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Haptics.tap()
                selectedTab = targetTab
            } label: {
                HStack {
                    Text(ctaTitle)
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

    private var hrvAssessment: String {
        guard let hrv = health.heartRateVariability else { return "No Sample" }
        return hrv >= 70 ? "High Recovery" : hrv >= 45 ? "Balanced" : "Rest Needed"
    }

    private var formattedSleepValue: String {
        guard let hours = health.sleepTotalHours, hours > 0 else { return "—" }
        let wholeHours = Int(hours)
        let mins = Int(((hours - Double(wholeHours)) * 60).rounded())
        return "\(wholeHours)h \(mins)m"
    }
}

// MARK: - Native Apple Biometric Metric Sheet
private struct BiometricDetailSheet: View {
    let metric: SelectedBiometricDetail
    @ObservedObject var health: HealthKitManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(headline)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
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
                            .font(.system(size: 26, weight: .bold, design: .rounded))
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

                Spacer()
            }
            .padding(20)
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
            return "Measured passively during deep rest and overnight sleep. Lower values indicate stronger stroke volume and parasympathetic balance."
        case .hrv:
            return "SDNN beat-to-beat variation reflects vagus nerve readiness. Higher HRV signals readiness for intense strength or HIIT blocks."
        case .vo2Max:
            return "Maximal oxygen uptake is the strongest clinical predictor of all-cause longevity and cardiovascular lifespan."
        case .sleep:
            return "Total restorative sleep duration excluding awake interruptions. Consistent wake times anchor circadian cortisol and testosterone."
        }
    }
}
