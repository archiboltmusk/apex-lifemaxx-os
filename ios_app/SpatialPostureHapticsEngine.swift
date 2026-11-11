import Foundation
import SwiftUI
import CoreMotion
import CoreHaptics
import Combine
import AVFoundation

public struct PostureSessionRecord: Codable, Identifiable {
    public let id: UUID
    public let date: Date
    public let durationSeconds: Int
    public let slouchEvents: Int
    public let neutralPitchDeg: Double
}

// MARK: - AirPods Spatial Head-Posture Coach & CoreHaptics Eccentric Tempo Engine
@MainActor
public final class SpatialPostureHapticsEngine: ObservableObject {
    public static let shared = SpatialPostureHapticsEngine()

    // AirPods Pro Spatial Posture State
    @Published public var isAirPodsAvailable: Bool = false
    @Published public var isMonitoringPosture: Bool = false
    @Published public var headPitchDegrees: Double = 0.0
    @Published public var neutralPitchOffsetDeg: Double = 0.0
    @Published public var isForwardHeadSlouching: Bool = false
    @Published public var slouchEventsCount: Int = 0
    @Published public var postureStatusLabel: String = "Wear AirPods Pro for spatial cervical posture"
    @Published public var sessionHistory: [PostureSessionRecord] = []

    // CoreHaptics & Audio Eccentric Tempo Metronome State
    @Published public var isTempoHapticsEnabled: Bool = false
    @Published public var isTempoAudioEnabled: Bool = true

    private let headphoneManager = CMHeadphoneMotionManager()
    private var hapticEngine: CHHapticEngine?
    private var slouchFrames: Int = 0
    private var latestRawPitchDeg: Double = 0.0
    private var postureSessionStartedAt: Date? = nil
    private var tempoTask: Task<Void, Never>?

    private let historyKey = "apex_posture_sessions_v1"
    private let offsetKey = "apex_posture_neutral_deg_v1"
    private var audioEngine: AVAudioEngine?
    private var audioPlayerNode: AVAudioPlayerNode?
    private var lowClickBuffer: AVAudioPCMBuffer?
    private var highClickBuffer: AVAudioPCMBuffer?

    private init() {
        self.isAirPodsAvailable = headphoneManager.isDeviceMotionAvailable
        self.neutralPitchOffsetDeg = UserDefaults.standard.double(forKey: offsetKey)
        self.sessionHistory = Self.loadHistory()
        prepareHaptics()
    }

    public static func loadHistory() -> [PostureSessionRecord] {
        guard let d = UserDefaults.standard.data(forKey: "apex_posture_sessions_v1"),
              let dec = try? JSONDecoder().decode([PostureSessionRecord].self, from: d) else {
            return []
        }
        return dec
    }

    public static func saveHistory(_ items: [PostureSessionRecord]) {
        if let d = try? JSONEncoder().encode(Array(items.prefix(30))) {
            UserDefaults.standard.set(d, forKey: "apex_posture_sessions_v1")
        }
    }

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        hapticEngine = try? CHHapticEngine()
        try? hapticEngine?.start()
    }

    public func calibrateNeutralPosture() {
        neutralPitchOffsetDeg = (latestRawPitchDeg * 10).rounded() / 10
        UserDefaults.standard.set(neutralPitchOffsetDeg, forKey: offsetKey)
        headPitchDegrees = 0.0
        slouchFrames = 0
        isForwardHeadSlouching = false
        postureStatusLabel = String(format: "Neutral zeroed at %.1f°", neutralPitchOffsetDeg)
        Haptics.success()
    }

    public func resetNeutralCalibration() {
        neutralPitchOffsetDeg = 0.0
        UserDefaults.standard.set(0.0, forKey: offsetKey)
        postureStatusLabel = "Neutral reset to horizon (0°)"
        Haptics.tap()
    }

    public func togglePostureMonitoring() {
        if isMonitoringPosture {
            stopPostureMonitoring()
        } else {
            startPostureMonitoring()
        }
    }

    public func startPostureMonitoring() {
        isAirPodsAvailable = headphoneManager.isDeviceMotionAvailable
        guard headphoneManager.isDeviceMotionAvailable else {
            postureStatusLabel = "Connect AirPods Pro / Max to track head pitch"
            Haptics.warning()
            return
        }

        isMonitoringPosture = true
        postureSessionStartedAt = Date()
        slouchEventsCount = 0
        postureStatusLabel = "Tracking cervical angle vs. neutral"
        slouchFrames = 0

        headphoneManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self = self, let motion = motion else { return }
            let rawDeg = motion.attitude.pitch * 180.0 / .pi
            self.latestRawPitchDeg = rawDeg
            let relDeg = rawDeg - self.neutralPitchOffsetDeg
            self.headPitchDegrees = (relDeg * 10).rounded() / 10

            // Sustained downward neck flexion (< -18 deg relative to calibrated neutral)
            if relDeg < -18.0 {
                self.slouchFrames += 1
                if self.slouchFrames == 25 {
                    self.isForwardHeadSlouching = true
                    self.slouchEventsCount += 1
                    self.postureStatusLabel = "Forward-head detected · Tuck chin"
                    self.playPostureNudgeHaptic()
                }
            } else {
                self.slouchFrames = 0
                if self.isForwardHeadSlouching {
                    self.isForwardHeadSlouching = false
                    self.postureStatusLabel = "Cervical alignment restored"
                }
            }
        }
    }

    public func stopPostureMonitoring() {
        headphoneManager.stopDeviceMotionUpdates()
        if let started = postureSessionStartedAt {
            let elapsed = Int(Date().timeIntervalSince(started))
            if elapsed >= 15 {
                let record = PostureSessionRecord(
                    id: UUID(),
                    date: Date(),
                    durationSeconds: elapsed,
                    slouchEvents: slouchEventsCount,
                    neutralPitchDeg: neutralPitchOffsetDeg
                )
                sessionHistory.insert(record, at: 0)
                Self.saveHistory(sessionHistory)
            }
        }
        postureSessionStartedAt = nil
        isMonitoringPosture = false
        isForwardHeadSlouching = false
        postureStatusLabel = isAirPodsAvailable ? "Spatial posture standby" : "Wear AirPods Pro for spatial cervical posture"
    }

    // MARK: - CoreHaptics & Audio Eyes-Free Eccentric Tempo Metronome (3-1-1s Cadence)
    public func startEccentricMetronome() {
        tempoTask?.cancel()
        guard isTempoHapticsEnabled else { return }
        if isTempoAudioEnabled { prepareMetronomeAudio() }

        tempoTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self, self.isTempoHapticsEnabled else { break }
                // 3 gentle eccentric lowering pulses
                for _ in 0..<3 {
                    if Task.isCancelled { break }
                    if self.isTempoAudioEnabled { self.playAudioClick(high: false) }
                    await self.playTransientHaptic(intensity: 0.45, sharpness: 0.35)
                    try? await Task.sleep(nanoseconds: 950_000_000)
                }
                if Task.isCancelled { break }
                // Strong bottom drive cue
                if self.isTempoAudioEnabled { self.playAudioClick(high: true) }
                await self.playTransientHaptic(intensity: 0.95, sharpness: 0.9)
                try? await Task.sleep(nanoseconds: 1_200_000_000)
            }
        }
    }

    public func stopEccentricMetronome() {
        tempoTask?.cancel()
        tempoTask = nil
        audioEngine?.stop()
    }

    private func prepareMetronomeAudio() {
        if audioEngine == nil {
            let engine = AVAudioEngine()
            let player = AVAudioPlayerNode()
            engine.attach(player)
            let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
            engine.connect(player, to: engine.mainMixerNode, format: format)
            audioEngine = engine
            audioPlayerNode = player
            lowClickBuffer = makeClickBuffer(freq: 660, duration: 0.045, gain: 0.22, format: format)
            highClickBuffer = makeClickBuffer(freq: 1046.5, duration: 0.07, gain: 0.32, format: format)
        }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        if audioEngine?.isRunning != true {
            try? audioEngine?.start()
        }
    }

    private func playAudioClick(high: Bool) {
        guard let player = audioPlayerNode,
              let buf = high ? highClickBuffer : lowClickBuffer else { return }
        if audioEngine?.isRunning != true { prepareMetronomeAudio() }
        player.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    private func makeClickBuffer(freq: Double, duration: Double, gain: Float, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let count = AVAudioFrameCount(format.sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count) else { return nil }
        buffer.frameLength = count
        guard let ch = buffer.floatChannelData?[0] else { return nil }
        let sr = format.sampleRate
        for i in 0..<Int(count) {
            let t = Double(i) / sr
            let env = Float(exp(-t * 48.0))
            ch[i] = Float(sin(2.0 * .pi * freq * t)) * gain * env
        }
        return buffer
    }

    public func playPostureNudgeHaptic() {
        Task {
            await playTransientHaptic(intensity: 0.8, sharpness: 0.65)
            try? await Task.sleep(nanoseconds: 140_000_000)
            await playTransientHaptic(intensity: 0.8, sharpness: 0.65)
        }
    }

    private func playTransientHaptic(intensity: Float, sharpness: Float) async {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            Haptics.tap(.medium)
            return
        }
        do {
            if hapticEngine == nil { prepareHaptics() }
            try await hapticEngine?.start()
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try hapticEngine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            Haptics.tap(.light)
        }
    }
}

// MARK: - Interactive AirPods Spatial Posture & Eccentric Metronome Sheet
public struct PostureCoachSheet: View {
    @ObservedObject private var posture = SpatialPostureHapticsEngine.shared
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section("Cervical Spatial Alignment (AirPods Pro / Max)") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(format: "%+.1f°", posture.headPitchDegrees))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(posture.isForwardHeadSlouching ? ApexTheme.accentAmber : ApexTheme.standCyan)
                            Text(posture.postureStatusLabel)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            posture.togglePostureMonitoring()
                        } label: {
                            Text(posture.isMonitoringPosture ? "Stop" : "Start")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(posture.isMonitoringPosture ? ApexTheme.accentAmber : ApexTheme.accentVolt)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)

                    if posture.isMonitoringPosture {
                        HStack {
                            Button("Calibrate Current Head Neutral") {
                                posture.calibrateNeutralPosture()
                            }
                            .foregroundStyle(ApexTheme.accentVolt)
                            Spacer()
                            Text("Slouches: \(posture.slouchEventsCount)")
                                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    } else if posture.neutralPitchOffsetDeg != 0 {
                        Button("Reset Calibrated Horizon (\(String(format: "%.1f°", posture.neutralPitchOffsetDeg)))", role: .destructive) {
                            posture.resetNeutralCalibration()
                        }
                    }
                }

                Section("3-1-1s Lifting Tempo Metronome") {
                    Toggle("Enable Tactile + Audio Metronome", isOn: Binding(
                        get: { posture.isTempoHapticsEnabled },
                        set: { enabled in
                            posture.isTempoHapticsEnabled = enabled
                            if enabled {
                                posture.startEccentricMetronome()
                            } else {
                                posture.stopEccentricMetronome()
                            }
                        }
                    ))
                    Toggle("Synthesize Audio Click Cues", isOn: $posture.isTempoAudioEnabled)
                }

                if !posture.sessionHistory.isEmpty {
                    Section("Posture Sessions") {
                        ForEach(posture.sessionHistory.prefix(10)) { s in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("\(s.durationSeconds / 60)m \(s.durationSeconds % 60)s tracked")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(s.slouchEvents) alerts")
                                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                                    .foregroundStyle(s.slouchEvents == 0 ? ApexTheme.accentEmerald : ApexTheme.accentAmber)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Spatial Posture & Tempo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
