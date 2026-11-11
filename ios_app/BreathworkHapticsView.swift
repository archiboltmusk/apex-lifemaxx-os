import SwiftUI
import CoreHaptics
import Combine
import AVFoundation

public struct BreathworkSessionRecord: Codable, Identifiable {
    public let id: UUID
    public let date: Date
    public let protocolName: String
    public let durationMinutes: Double
    public let cyclesCompleted: Int
}

public enum BreathworkHistoryStore {
    private static let key = "apex_breathwork_history_v1"

    public static func load() -> [BreathworkSessionRecord] {
        guard let d = UserDefaults.standard.data(forKey: key),
              let dec = try? JSONDecoder().decode([BreathworkSessionRecord].self, from: d) else {
            return []
        }
        return dec
    }

    public static func save(_ items: [BreathworkSessionRecord]) {
        if let d = try? JSONEncoder().encode(Array(items.prefix(40))) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }
}

public struct BreathworkPattern: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let subtitle: String
    public let benefit: String
    public let inhaleSec: Double
    public let holdTopSec: Double
    public let exhaleSec: Double
    public let holdBottomSec: Double
    public let accentColor: Color

    public var cycleDuration: Double {
        inhaleSec + holdTopSec + exhaleSec + holdBottomSec
    }

    public static let presets: [BreathworkPattern] = [
        BreathworkPattern(
            id: "resonance_55",
            name: "HRV Resonance",
            subtitle: "5.5s In · 5.5s Out",
            benefit: "Peak RSA vagal tone (~5.5 breaths/min)",
            inhaleSec: 5.5,
            holdTopSec: 0.0,
            exhaleSec: 5.5,
            holdBottomSec: 0.0,
            accentColor: ApexTheme.standCyan
        ),
        BreathworkPattern(
            id: "phys_sigh",
            name: "Physiological Sigh",
            subtitle: "3s In · 1s Top-Up · 6s Out · 1s Pause",
            benefit: "Alveolar reinflation & rapid sympathetic braking",
            inhaleSec: 3.0,
            holdTopSec: 1.0,
            exhaleSec: 6.0,
            holdBottomSec: 1.0,
            accentColor: ApexTheme.accentEmerald
        ),
        BreathworkPattern(
            id: "box_4444",
            name: "Tactical Box",
            subtitle: "4s In · 4s Hold · 4s Out · 4s Hold",
            benefit: "CO2 tolerance & acute stress reset",
            inhaleSec: 4.0,
            holdTopSec: 4.0,
            exhaleSec: 4.0,
            holdBottomSec: 4.0,
            accentColor: ApexTheme.accentVolt
        ),
        BreathworkPattern(
            id: "oxygen_surge",
            name: "Oxygen Surge",
            subtitle: "2s In · 2s Out (Energizing)",
            benefit: "Pre-session alertness & sympathetic primer",
            inhaleSec: 2.0,
            holdTopSec: 0.0,
            exhaleSec: 2.0,
            holdBottomSec: 0.0,
            accentColor: ApexTheme.moveCrimson
        ),
        BreathworkPattern(
            id: "sleep_478",
            name: "4-7-8 Down-Reg",
            subtitle: "4s In · 7s Hold · 8s Out",
            benefit: "Extended exhale for pre-sleep onset",
            inhaleSec: 4.0,
            holdTopSec: 7.0,
            exhaleSec: 8.0,
            holdBottomSec: 0.0,
            accentColor: ApexTheme.accentIndigo
        )
    ]
}

@MainActor
public final class BreathworkSessionController: ObservableObject {
    public enum Phase: String {
        case ready = "Ready"
        case inhale = "Inhale"
        case holdTop = "Hold"
        case exhale = "Exhale"
        case holdBottom = "Hold Empty"
        case completed = "Session Complete"
    }

    @Published public var selectedPattern: BreathworkPattern = BreathworkPattern.presets[0]
    @Published public var targetMinutes: Int = 3
    @Published public var isRunning: Bool = false
    @Published public var hapticsEnabled: Bool = true
    @Published public var audioCuesEnabled: Bool = true
    @Published public var currentPhase: Phase = .ready
    @Published public var phaseProgress: Double = 0
    @Published public var breathScale: CGFloat = 0.56
    @Published public var elapsedSeconds: Double = 0
    @Published public var cyclesCompleted: Int = 0
    @Published public var healthSaveStatus: String? = nil
    @Published public var sessionHistory: [BreathworkSessionRecord] = BreathworkHistoryStore.load()

    private var engine: CHHapticEngine?
    private var audioEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayerNode?
    private var inhaleChime: AVAudioPCMBuffer?
    private var holdChime: AVAudioPCMBuffer?
    private var exhaleChime: AVAudioPCMBuffer?
    private var timerCancellable: AnyCancellable?
    private var phaseElapsed: Double = 0
    private var lastTickDate: Date?
    private var hapticsSupported: Bool = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    public init() {
        prepareHapticEngine()
    }

    public func stopAll() {
        isRunning = false
        timerCancellable?.cancel()
        timerCancellable = nil
        audioEngine?.stop()
        currentPhase = .ready
        phaseProgress = 0
        breathScale = 0.56
    }

    public func toggleSession(health: HealthKitManager) {
        if isRunning {
            finishSession(health: health)
        } else {
            startSession(health: health)
        }
    }

    public func startSession(health: HealthKitManager) {
        prepareHapticEngine()
        elapsedSeconds = 0
        phaseElapsed = 0
        cyclesCompleted = 0
        healthSaveStatus = nil
        isRunning = true
        enterPhase(.inhale)
        lastTickDate = Date()

        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                self?.step(now: now, health: health)
            }
    }

    public func finishSession(health: HealthKitManager) {
        let loggedMins = elapsedSeconds / 60.0
        let protoName = selectedPattern.name
        let doneCycles = cyclesCompleted
        stopAll()
        currentPhase = .completed
        if loggedMins >= 0.5 {
            let record = BreathworkSessionRecord(
                id: UUID(),
                date: Date(),
                protocolName: protoName,
                durationMinutes: (loggedMins * 10).rounded() / 10,
                cyclesCompleted: doneCycles
            )
            sessionHistory.insert(record, at: 0)
            BreathworkHistoryStore.save(sessionHistory)
            Haptics.success()
            Task {
                let saved = await health.logMindfulSession(minutes: loggedMins)
                self.healthSaveStatus = saved
                    ? String(format: "Saved %.1f min Mindful Session to Apple Health.", loggedMins)
                    : String(format: "Completed %.1f min breathwork (connect Apple Health on Summary to write Mindful Minutes).", loggedMins)
            }
        } else {
            healthSaveStatus = "Session under 30s was not written to Apple Health."
        }
    }

    private func step(now: Date, health: HealthKitManager) {
        guard isRunning else { return }
        let dt = min(0.25, now.timeIntervalSince(lastTickDate ?? now))
        lastTickDate = now
        elapsedSeconds += dt
        phaseElapsed += dt

        let targetSec = Double(targetMinutes * 60)
        if elapsedSeconds >= targetSec {
            finishSession(health: health)
            return
        }

        let dur = currentPhaseDuration()
        let progress = dur > 0 ? min(1.0, phaseElapsed / dur) : 1.0
        phaseProgress = progress

        switch currentPhase {
        case .inhale:
            breathScale = CGFloat(0.56 + 0.44 * progress)
        case .holdTop:
            breathScale = 1.0
        case .exhale:
            breathScale = CGFloat(1.0 - 0.44 * progress)
        case .holdBottom:
            breathScale = 0.56
        case .ready, .completed:
            breathScale = 0.56
        }

        if phaseElapsed >= dur {
            advancePhase()
        }
    }

    private func currentPhaseDuration() -> Double {
        switch currentPhase {
        case .inhale: return selectedPattern.inhaleSec
        case .holdTop: return selectedPattern.holdTopSec
        case .exhale: return selectedPattern.exhaleSec
        case .holdBottom: return selectedPattern.holdBottomSec
        case .ready, .completed: return 0
        }
    }

    private func advancePhase() {
        phaseElapsed = 0
        switch currentPhase {
        case .inhale:
            if selectedPattern.holdTopSec > 0 { enterPhase(.holdTop) }
            else { enterPhase(.exhale) }
        case .holdTop:
            enterPhase(.exhale)
        case .exhale:
            if selectedPattern.holdBottomSec > 0 {
                enterPhase(.holdBottom)
            } else {
                cyclesCompleted += 1
                enterPhase(.inhale)
            }
        case .holdBottom:
            cyclesCompleted += 1
            enterPhase(.inhale)
        case .ready, .completed:
            break
        }
    }

    private func enterPhase(_ next: Phase) {
        currentPhase = next
        phaseProgress = 0
        if audioCuesEnabled {
            playAudioChime(for: next)
        }
        if hapticsEnabled {
            playPhaseHaptics(for: next)
        }
    }

    private func prepareAudioChimes() {
        if audioEngine == nil {
            let eng = AVAudioEngine()
            let player = AVAudioPlayerNode()
            eng.attach(player)
            let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
            eng.connect(player, to: eng.mainMixerNode, format: format)
            audioEngine = eng
            audioPlayer = player
            inhaleChime = makeChimeBuffer(freq: 396.0, duration: 0.28, gain: 0.16, format: format)
            holdChime = makeChimeBuffer(freq: 528.0, duration: 0.20, gain: 0.12, format: format)
            exhaleChime = makeChimeBuffer(freq: 285.0, duration: 0.36, gain: 0.16, format: format)
        }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        if audioEngine?.isRunning != true {
            try? audioEngine?.start()
        }
    }

    private func playAudioChime(for phase: Phase) {
        let buf: AVAudioPCMBuffer? = {
            switch phase {
            case .inhale: return inhaleChime
            case .holdTop, .holdBottom: return holdChime
            case .exhale: return exhaleChime
            case .ready, .completed: return nil
            }
        }()
        if audioEngine == nil || audioEngine?.isRunning != true {
            prepareAudioChimes()
        }
        let chosen = buf ?? {
            switch phase {
            case .inhale: return inhaleChime
            case .holdTop, .holdBottom: return holdChime
            case .exhale: return exhaleChime
            default: return nil
            }
        }()
        guard let player = audioPlayer, let buffer = chosen else { return }
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    private func makeChimeBuffer(freq: Double, duration: Double, gain: Float, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let count = AVAudioFrameCount(format.sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count) else { return nil }
        buffer.frameLength = count
        guard let ch = buffer.floatChannelData?[0] else { return nil }
        let sr = format.sampleRate
        for i in 0..<Int(count) {
            let t = Double(i) / sr
            let attack = min(1.0, t / 0.015)
            let decay = exp(-t * 9.5)
            let fundamental = sin(2.0 * .pi * freq * t)
            let overtone = 0.25 * sin(2.0 * .pi * (freq * 1.5) * t)
            ch[i] = Float((fundamental + overtone) * attack * decay) * gain
        }
        return buffer
    }

    private func prepareHapticEngine() {
        guard hapticsSupported, engine == nil else { return }
        do {
            let eng = try CHHapticEngine()
            eng.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            try eng.start()
            self.engine = eng
        } catch {
            self.engine = nil
        }
    }

    private func playPhaseHaptics(for phase: Phase) {
        guard hapticsSupported, let engine else {
            // Clean UIImpact fallback when CoreHaptics is unavailable (Simulator / older devices)
            switch phase {
            case .inhale: Haptics.tap(.medium)
            case .exhale: Haptics.tap(.soft)
            case .holdTop, .holdBottom: Haptics.selection()
            case .ready, .completed: break
            }
            return
        }

        do {
            try engine.start()
            var events: [CHHapticEvent] = []
            var curves: [CHHapticParameterCurve] = []

            switch phase {
            case .inhale:
                let dur = max(0.5, selectedPattern.inhaleSec)
                events.append(CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.25),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35)
                    ],
                    relativeTime: 0,
                    duration: dur
                ))
                curves.append(CHHapticParameterCurve(
                    parameterID: .hapticIntensityControl,
                    controlPoints: [
                        .init(relativeTime: 0, value: 0.18),
                        .init(relativeTime: dur * 0.65, value: 0.65),
                        .init(relativeTime: dur, value: 0.90)
                    ],
                    relativeTime: 0
                ))
            case .exhale:
                let dur = max(0.5, selectedPattern.exhaleSec)
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.55),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25)
                    ],
                    relativeTime: 0
                ))
                events.append(CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.50),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15)
                    ],
                    relativeTime: 0.08,
                    duration: max(0.4, dur - 0.08)
                ))
                curves.append(CHHapticParameterCurve(
                    parameterID: .hapticIntensityControl,
                    controlPoints: [
                        .init(relativeTime: 0.08, value: 0.60),
                        .init(relativeTime: dur, value: 0.08)
                    ],
                    relativeTime: 0
                ))
            case .holdTop, .holdBottom:
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.65),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                    ],
                    relativeTime: 0
                ))
            case .ready, .completed:
                break
            }

            guard !events.isEmpty else { return }
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            Haptics.selection()
        }
    }
}

public struct BreathworkHapticsView: View {
    @ObservedObject private var health = HealthKitManager.shared
    @ObservedObject private var ble = BLEHeartRateMonitor.shared
    @StateObject private var controller = BreathworkSessionController()
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    pacerRingCard
                    liveSensorStrip
                    patternPicker
                    sessionSettingsCard
                    if let status = controller.healthSaveStatus {
                        Text(status)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ApexTheme.accentEmerald)
                            .multilineTextAlignment(.center)
                            .appleCard(padding: 14, cornerRadius: 16)
                    }
                    if !controller.sessionHistory.isEmpty {
                        historySection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(ApexTheme.background.ignoresSafeArea())
            .navigationTitle("HRV Breathwork Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        controller.stopAll()
                        dismiss()
                    }
                }
            }
            .onDisappear {
                controller.stopAll()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var pacerRingCard: some View {
        let pattern = controller.selectedPattern
        let remainingSec = max(0, controller.targetMinutes * 60 - Int(controller.elapsedSeconds.rounded()))
        let mins = remainingSec / 60
        let secs = remainingSec % 60

        return VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pattern.name.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(pattern.accentColor)
                    Text(pattern.subtitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Text(String(format: "%d:%02d", mins, secs))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }

            ZStack {
                Circle()
                    .stroke(pattern.accentColor.opacity(0.18), lineWidth: 12)
                    .frame(width: 210, height: 210)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [pattern.accentColor.opacity(0.55), pattern.accentColor.opacity(0.08)],
                            center: .center,
                            startRadius: 10,
                            endRadius: 105
                        )
                    )
                    .frame(width: 204, height: 204)
                    .scaleEffect(controller.breathScale)
                    .animation(.linear(duration: 0.06), value: controller.breathScale)

                VStack(spacing: 4) {
                    Text(controller.currentPhase.rawValue)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("\(controller.cyclesCompleted) cycles")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)

            Button {
                controller.toggleSession(health: health)
            } label: {
                Label(
                    controller.isRunning ? "Finish & Log Mindful Session" : "Start Closed-Eyes Pacer",
                    systemImage: controller.isRunning ? "stop.circle.fill" : "play.circle.fill"
                )
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(controller.isRunning ? ApexTheme.accentAmber : pattern.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .appleCard(padding: 18, cornerRadius: 22)
    }

    private var liveSensorStrip: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("LIVE HR")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ApexTheme.moveCrimson)
                if let bpm = ble.liveBPM {
                    Text("\(bpm) bpm")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                } else if let rhr = health.restingHeartRate {
                    Text("\(Int(rhr.rounded())) bpm (RHR)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                } else {
                    Text("Awaiting Sensor")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("RMSSD / HRV")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ApexTheme.standCyan)
                if let rmssd = ble.liveRMSSD {
                    Text("\(Int(rmssd.rounded())) ms")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                } else if let hrv = health.heartRateVariability {
                    Text("\(Int(hrv.rounded())) ms (SDNN)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                } else {
                    Text("Pair BLE Strap / Watch")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .appleCard(padding: 14, cornerRadius: 18)
    }

    private var patternPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cadence Protocols")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            ForEach(BreathworkPattern.presets) { p in
                let selected = controller.selectedPattern.id == p.id
                Button {
                    Haptics.selection()
                    if !controller.isRunning {
                        controller.selectedPattern = p
                    }
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(p.accentColor)
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("\(p.subtitle) · \(p.benefit)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(p.accentColor)
                        }
                    }
                    .padding(12)
                    .background(selected ? ApexTheme.elevatedSurface : ApexTheme.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(selected ? p.accentColor.opacity(0.6) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(controller.isRunning)
            }
        }
    }

    private var sessionSettingsCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Duration")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                Picker("Duration", selection: $controller.targetMinutes) {
                    Text("3 min").tag(3)
                    Text("5 min").tag(5)
                    Text("10 min").tag(10)
                }
                .pickerStyle(.segmented)
                .frame(width: 195)
                .disabled(controller.isRunning)
            }

            Toggle("Closed-Eyes CoreHaptics Ramp", isOn: $controller.hapticsEnabled)
                .font(.system(size: 14, weight: .medium))
                .tint(ApexTheme.standCyan)

            Toggle("Soft Harmonic Audio Chimes", isOn: $controller.audioCuesEnabled)
                .font(.system(size: 14, weight: .medium))
                .tint(ApexTheme.standCyan)
        }
        .appleCard(padding: 14, cornerRadius: 18)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Breathwork Sessions")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            ForEach(controller.sessionHistory.prefix(6)) { s in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.protocolName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(s.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(String(format: "%.1fm · %d cyc", s.durationMinutes, s.cyclesCompleted))
                        .font(.system(size: 12, weight: .bold).monospacedDigit())
                        .foregroundStyle(ApexTheme.standCyan)
                }
                .appleCard(padding: 12, cornerRadius: 14)
            }
        }
    }
}
