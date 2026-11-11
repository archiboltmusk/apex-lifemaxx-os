import Foundation
import CoreMotion
import CoreHaptics
import Combine

// MARK: - AirPods Spatial Head-Posture Coach & CoreHaptics Eccentric Tempo Engine
@MainActor
public final class SpatialPostureHapticsEngine: ObservableObject {
    public static let shared = SpatialPostureHapticsEngine()

    // AirPods Pro Spatial Posture State
    @Published public var isAirPodsAvailable: Bool = false
    @Published public var isMonitoringPosture: Bool = false
    @Published public var headPitchDegrees: Double = 0.0
    @Published public var isForwardHeadSlouching: Bool = false
    @Published public var slouchEventsCount: Int = 0
    @Published public var postureStatusLabel: String = "Wear AirPods Pro for spatial cervical posture"

    // CoreHaptics Eccentric Tempo Metronome State
    @Published public var isTempoHapticsEnabled: Bool = false

    private let headphoneManager = CMHeadphoneMotionManager()
    private var hapticEngine: CHHapticEngine?
    private var slouchFrames: Int = 0
    private var tempoTask: Task<Void, Never>?

    private init() {
        self.isAirPodsAvailable = headphoneManager.isDeviceMotionAvailable
        prepareHaptics()
    }

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        hapticEngine = try? CHHapticEngine()
        try? hapticEngine?.start()
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
        postureStatusLabel = "Calibrated · Tracking cervical angle"
        slouchFrames = 0

        headphoneManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self = self, let motion = motion else { return }
            let pitchDeg = motion.attitude.pitch * 180.0 / .pi
            self.headPitchDegrees = (pitchDeg * 10).rounded() / 10

            // Sustained downward neck flexion (< -18 deg)
            if pitchDeg < -18.0 {
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
        isMonitoringPosture = false
        isForwardHeadSlouching = false
        postureStatusLabel = isAirPodsAvailable ? "Spatial posture standby" : "Wear AirPods Pro for spatial cervical posture"
    }

    // MARK: - CoreHaptics Eyes-Free Eccentric Tempo Metronome (3-1-1s Cadence)
    public func startEccentricMetronome() {
        tempoTask?.cancel()
        guard isTempoHapticsEnabled else { return }

        tempoTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self, self.isTempoHapticsEnabled else { break }
                // 3 gentle eccentric lowering pulses
                for _ in 0..<3 {
                    if Task.isCancelled { break }
                    await self.playTransientHaptic(intensity: 0.45, sharpness: 0.35)
                    try? await Task.sleep(nanoseconds: 950_000_000)
                }
                if Task.isCancelled { break }
                // Strong bottom drive cue
                await self.playTransientHaptic(intensity: 0.95, sharpness: 0.9)
                try? await Task.sleep(nanoseconds: 1_200_000_000)
            }
        }
    }

    public func stopEccentricMetronome() {
        tempoTask?.cancel()
        tempoTask = nil
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
