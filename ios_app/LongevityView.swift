import SwiftUI
import Combine

// MARK: - Longevity, Bloodwork PhenoAge, Circadian Intelligence & Bonjour Mac Continuity
public struct LongevityView: View {
    @ObservedObject private var health = HealthKitManager.shared
    @ObservedObject private var router = ApexNavigationRouter.shared

    // Interactive Dead Hang Timer State
    @AppStorage("apex_best_deadhang_sec") private var bestDeadHangSeconds: Int = 0
    @State private var deadHangSeconds: Int = 0
    @State private var isDeadHangRunning: Bool = false

    // Circadian Calibration
    @AppStorage("apex_wake_minutes") private var wakeMinutesFromMidnight: Int = 390
    @State private var showCompanionConfig: Bool = false
    @State private var showBloodworkOCR: Bool = false
    @State private var syncJustCompleted: Bool = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    biologicalAgeCard

                    bloodworkOCRCard

                    deadHangCard

                    circadianCard

                    companionSyncCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 32)
            }
            .background(ApexTheme.background)
            .navigationTitle("Longevity")
            .navigationBarTitleDisplayMode(.large)
            .onReceive(timer) { _ in
                if isDeadHangRunning {
                    deadHangSeconds += 1
                    if deadHangSeconds > bestDeadHangSeconds {
                        bestDeadHangSeconds = deadHangSeconds
                        health.persistWidgetSnapshot()
                    }
                    if deadHangSeconds == 120 {
                        Haptics.success()
                        health.syncEventToMac(extraPayload: ["deadHangBest": bestDeadHangSeconds])
                    }
                }
            }
            .onChange(of: router.shouldAutoStartDeadHang) { _, start in
                if start {
                    deadHangSeconds = 0
                    isDeadHangRunning = true
                    router.shouldAutoStartDeadHang = false
                }
            }
            .sheet(isPresented: $showCompanionConfig) {
                CompanionSettingsSheet(health: health)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showBloodworkOCR) {
                BloodworkOCRView()
            }
        }
    }

    // MARK: - 1. Dual Biological Fitness Age & Clinical PhenoAge Card
    private var biologicalAgeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Biological Fitness Age")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Wearable Vitals + Epigenetic Clinical Panel")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "hourglass")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(ApexTheme.accentEmerald)
            }

            HStack(alignment: .lastTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FITNESS AGE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    if let bio = health.biologicalAge {
                        Text(String(format: "%.1f yrs", bio))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(ApexTheme.accentEmerald)
                    } else {
                        Text("—")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                if let clinical = health.clinicalPhenoAge {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LAB PHENOAGE")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f yrs", clinical))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(ApexTheme.standCyan)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("Chronological")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button {
                            Haptics.tap()
                            health.chronologicalAge = max(16, health.chronologicalAge - 1)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary)
                        }
                        Text("\(Int(health.chronologicalAge))")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .frame(minWidth: 28)
                        Button {
                            Haptics.tap()
                            health.chronologicalAge = min(95, health.chronologicalAge + 1)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let bio = health.biologicalAge {
                let delta = bio - health.chronologicalAge
                HStack(spacing: 6) {
                    Image(systemName: delta <= 0 ? "arrow.down.right.circle.fill" : "arrow.up.right.circle.fill")
                        .foregroundStyle(delta <= 0 ? ApexTheme.accentEmerald : ApexTheme.accentAmber)
                    Text(delta <= 0
                         ? String(format: "%.1f years younger than chronological age", abs(delta))
                         : String(format: "%.1f years above baseline — increase Zone 2 cardio", delta))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
            } else {
                Text("Connect Apple Health or log an active workout to calculate your biological fitness age from live vitals.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .appleCard(padding: 18, cornerRadius: 22)
    }

    // MARK: - 2. Native VisionKit Lab Bloodwork OCR Trigger
    private var bloodworkOCRCard: some View {
        Button {
            Haptics.tap()
            showBloodworkOCR = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(ApexTheme.moveCrimson.opacity(0.16))
                        .frame(width: 44, height: 44)
                    Image(systemName: "drop.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ApexTheme.moveCrimson)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Bloodwork Lab OCR")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(health.clinicalPhenoAge != nil
                         ? "Clinical PhenoAge calibrated · Tap to rescan panel"
                         : "Scan paper lab results or PDFs for Albumin, hs-CRP & Glucose")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .appleCard(padding: 16, cornerRadius: 20)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 3. Centenarian Dead Hang Benchmark
    private var deadHangCard: some View {
        let targetSeconds = 120.0
        let progress = min(1.0, Double(deadHangSeconds) / targetSeconds)

        return VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dead Hang Endurance")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Grip strength & shoulder longevity · 2:00 benchmark")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Best \(formatMinSec(bestDeadHangSeconds))")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ApexTheme.accentVolt)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(ApexTheme.accentVolt.opacity(0.14))
                    .clipShape(Capsule())
            }

            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(ApexTheme.standCyan.opacity(0.18), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(ApexTheme.standCyan, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.3), value: progress)

                    Text(formatMinSec(deadHangSeconds))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                .frame(width: 84, height: 84)

                VStack(alignment: .leading, spacing: 10) {
                    Text(deadHangSeconds >= 120 ? "Centenarian target achieved" : "Hold with engaged shoulders until grip fatigues.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Button {
                            Haptics.tap(.medium)
                            let wasRunning = isDeadHangRunning
                            isDeadHangRunning.toggle()
                            if wasRunning {
                                health.syncEventToMac(extraPayload: ["deadHangBest": bestDeadHangSeconds])
                            }
                        } label: {
                            Text(isDeadHangRunning ? "Pause" : (deadHangSeconds > 0 ? "Resume" : "Start"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 9)
                                .background(isDeadHangRunning ? ApexTheme.accentAmber : ApexTheme.standCyan)
                                .clipShape(Capsule())
                        }

                        if deadHangSeconds > 0 {
                            Button {
                                Haptics.tap()
                                isDeadHangRunning = false
                                deadHangSeconds = 0
                            } label: {
                                Text("Reset")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(ApexTheme.elevatedSurface)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                Spacer()
            }
        }
        .appleCard(padding: 18, cornerRadius: 22)
    }

    // MARK: - 4. Circadian Window Card
    private var circadianCard: some View {
        let wakeHours = Double(wakeMinutesFromMidnight) / 60.0
        let peakStart = formatHourOfDay(wakeHours + 9.5)
        let peakEnd = formatHourOfDay(wakeHours + 11.5)
        let caffeineCutoff = formatHourOfDay(wakeHours + 7.5)
        let targetBedtime = formatHourOfDay(wakeHours + 16.0)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Circadian Timing")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Wake at \(formatHourOfDay(wakeHours))")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        Haptics.tap()
                        wakeMinutesFromMidnight = max(240, wakeMinutesFromMidnight - 30)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 28, height: 28)
                            .background(ApexTheme.elevatedSurface)
                            .clipShape(Circle())
                    }
                    Button {
                        Haptics.tap()
                        wakeMinutesFromMidnight = min(660, wakeMinutesFromMidnight + 30)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 28, height: 28)
                            .background(ApexTheme.elevatedSurface)
                            .clipShape(Circle())
                    }
                }
                .foregroundStyle(.white)
            }

            VStack(spacing: 10) {
                circadianRow(icon: "bolt.fill", color: ApexTheme.accentVolt, label: "Peak Strength Window", time: "\(peakStart) – \(peakEnd)")
                Divider().background(Color.white.opacity(0.08))
                circadianRow(icon: "cup.and.saucer.fill", color: ApexTheme.accentAmber, label: "Caffeine Cutoff", time: caffeineCutoff)
                Divider().background(Color.white.opacity(0.08))
                circadianRow(icon: "moon.stars.fill", color: ApexTheme.accentIndigo, label: "Optimal Bedtime", time: targetBedtime)
            }
        }
        .appleCard(padding: 18, cornerRadius: 22)
    }

    private func circadianRow(icon: String, color: Color, label: String, time: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 22)
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
            Spacer()
            Text(time)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 5. Bonjour Zero-Config Mac Companion Sync
    private var companionSyncCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "laptopcomputer.and.iphone")
                        .font(.system(size: 20))
                        .foregroundStyle(ApexTheme.standCyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("APEX Mac Companion")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(health.isMacReachable
                             ? "Connected · \(health.macDeviceName)"
                             : (health.discoveredMacs.isEmpty
                                ? "Stream vitals, workouts & scans over Wi-Fi"
                                : "Found \(health.discoveredMacs[0].name) via Bonjour"))
                            .font(.system(size: 12))
                            .foregroundStyle(health.isMacReachable ? ApexTheme.accentEmerald : .secondary)
                    }
                }
                Spacer()
                Button {
                    Haptics.tap()
                    health.startBonjourDiscovery()
                    showCompanionConfig = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(ApexTheme.elevatedSurface)
                        .clipShape(Circle())
                }
            }

            Button {
                Haptics.tap(.medium)
                health.broadcastToMac()
                syncJustCompleted = true
                Haptics.success()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    syncJustCompleted = false
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: syncJustCompleted ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                    Text(syncJustCompleted ? "Telemetry Sent to Mac" : "Sync Vitals & Scans Now")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(ApexTheme.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .appleCard(padding: 18, cornerRadius: 22)
    }

    private func formatMinSec(_ sec: Int) -> String {
        String(format: "%d:%02d", sec / 60, sec % 60)
    }

    private func formatHourOfDay(_ hour24: Double) -> String {
        let totalMinutes = Int((hour24 * 60).rounded()) % (24 * 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        let period = h >= 12 ? "PM" : "AM"
        let h12 = h % 12 == 0 ? 12 : h % 12
        return String(format: "%d:%02d %@", h12, m, period)
    }
}

private struct CompanionSettingsSheet: View {
    @ObservedObject var health: HealthKitManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if !health.discoveredMacs.isEmpty {
                    Section("Discovered on Local Wi-Fi (Bonjour)") {
                        ForEach(health.discoveredMacs) { mac in
                            Button {
                                Haptics.tap(.medium)
                                health.resolveAndConnect(endpoint: mac)
                            } label: {
                                HStack {
                                    Image(systemName: "desktopcomputer")
                                        .foregroundStyle(ApexTheme.standCyan)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mac.name)
                                            .foregroundStyle(.white)
                                        if let host = mac.host, let port = mac.port {
                                            Text("\(host):\(port)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text("Pair")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(ApexTheme.accentVolt)
                                }
                            }
                        }
                    }
                }

                Section("Desktop Connection") {
                    Toggle("Auto-Sync Biometrics", isOn: $health.isSyncingToMac)

                    HStack {
                        Text("Mac IP / Host")
                        Spacer()
                        TextField("127.0.0.1", text: $health.macHost)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.URL)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Port")
                        Spacer()
                        TextField("60159", value: $health.macServerPort, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Scan Network for Mac") {
                        Haptics.tap()
                        health.startBonjourDiscovery()
                    }
                    Button("Send Full Telemetry Packet") {
                        Haptics.tap()
                        health.broadcastToMac()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Mac Companion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
