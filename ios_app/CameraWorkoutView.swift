import SwiftUI
import Combine
import AVFoundation
import Vision
import HealthKit

// MARK: - Completed Workout Set Record
public struct WorkoutSetEntry: Codable, Identifiable {
    public let id: UUID
    public let exercise: String
    public let reps: Int
    public let durationSeconds: Int
    public let calories: Double
    public let peakVelocity: Double?
    public let velocityLossPercent: Int?
    public let date: Date
}

// MARK: - Native Apple Vision Optical Coach, VBT Tempo & Live Activity Tracker
public struct CameraWorkoutView: View {
    @ObservedObject private var health = HealthKitManager.shared
    @ObservedObject private var activityMgr = WorkoutActivityManager.shared
    @ObservedObject private var router = ApexNavigationRouter.shared
    @ObservedObject private var postureHaptics = SpatialPostureHapticsEngine.shared
    @ObservedObject private var bleHR = BLEHeartRateMonitor.shared
    @StateObject private var poseController = BodyPoseController()

    @State private var selectedExercise: ExerciseMode = .squats
    @State private var isVoiceEnabled: Bool = true
    @State private var isSavingWorkout: Bool = false
    @State private var savedBanner: String? = nil
    @State private var showWatchStrapSheet: Bool = false
    @AppStorage("apex_workout_load_kg") private var externalLoadKg: Double = 60.0
    @AppStorage("apex_athlete_height_cm") private var athleteHeightCm: Double = 175.0

    // Live Workout Timer
    @State private var sessionSeconds: Int = 0
    @State private var isTimerRunning: Bool = false
    @State private var workoutHistory: [WorkoutSetEntry] = WorkoutSetStore.load()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public enum ExerciseMode: String, CaseIterable, Identifiable {
        case squats = "Squats"
        case pushups = "Push-ups"
        case pullups = "Pull-ups"
        case ohp = "Overhead Press"
        case curls = "Bicep Curls"
        case rdl = "Romanian Deadlift"
        case lunges = "Lunges"
        case jacks = "Jumping Jacks"

        public var id: String { rawValue }

        var isBodyweight: Bool {
            switch self {
            case .pushups, .pullups, .jacks: return true
            default: return false
            }
        }

        var baselineRomMeters: Double {
            switch self {
            case .squats: return 0.58
            case .rdl, .lunges: return 0.54
            case .ohp: return 0.50
            case .curls: return 0.38
            case .pushups: return 0.34
            case .pullups: return 0.52
            case .jacks: return 0.64
            }
        }

        var kcalPerRep: Double {
            switch self {
            case .squats, .rdl: return 0.72
            case .pullups, .ohp: return 0.65
            case .lunges: return 0.60
            case .pushups: return 0.50
            case .jacks: return 0.45
            case .curls: return 0.35
            }
        }

        var workoutType: HKWorkoutActivityType {
            switch self {
            case .jacks: return .highIntensityIntervalTraining
            default: return .traditionalStrengthTraining
            }
        }
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    exerciseSelector

                    if activityMgr.isRestTimerRunning {
                        restCountdownPill
                    }

                    viewfinderHero

                    kinematicMetricsBar

                    sessionControls

                    if !workoutHistory.isEmpty {
                        completedSetsSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 32)
            }
            .background(ApexTheme.background)
            .navigationTitle("Train")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        Button {
                            Haptics.tap()
                            postureHaptics.isTempoHapticsEnabled.toggle()
                            if postureHaptics.isTempoHapticsEnabled {
                                postureHaptics.startEccentricMetronome()
                            } else {
                                postureHaptics.stopEccentricMetronome()
                            }
                        } label: {
                            Image(systemName: "metronome.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(postureHaptics.isTempoHapticsEnabled ? ApexTheme.standCyan : .secondary)
                        }
                        .accessibilityLabel("3-1-1s Tactile Tempo Metronome")

                        Button {
                            Haptics.tap()
                            showWatchStrapSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "applewatch")
                                    .font(.system(size: 13, weight: .semibold))
                                if let bpm = bleHR.liveBPM {
                                    Text("\(bpm)")
                                        .font(.system(size: 12, weight: .bold).monospacedDigit())
                                }
                            }
                            .foregroundStyle(bleHR.isConnected ? ApexTheme.moveCrimson : .white)
                        }
                        .accessibilityLabel("Apple Watch & BLE Chest Strap")

                        Button {
                            Haptics.tap()
                            isVoiceEnabled.toggle()
                            poseController.voiceCoachingEnabled = isVoiceEnabled
                        } label: {
                            Image(systemName: isVoiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(isVoiceEnabled ? ApexTheme.accentVolt : .secondary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showWatchStrapSheet) {
                ChestStrapWatchSheet(activeWorkoutTitle: selectedExercise.rawValue)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .onReceive(timer) { _ in
                if isTimerRunning {
                    sessionSeconds += 1
                    activityMgr.updateSet(
                        reps: poseController.repCount,
                        elapsedSeconds: sessionSeconds,
                        velocity: poseController.concentricVelocity,
                        velocityDropPercent: poseController.velocityLossPercent
                    )
                }
            }
            .onAppear {
                poseController.externalLoadKg = externalLoadKg
                poseController.athleteHeightCm = athleteHeightCm
                poseController.bodyWeightKg = health.bodyWeightKg ?? 75.0
            }
            .onChange(of: externalLoadKg) { _, val in
                poseController.externalLoadKg = val
            }
            .onChange(of: athleteHeightCm) { _, val in
                poseController.athleteHeightCm = val
            }
            .onChange(of: selectedExercise) { _, mode in
                poseController.setExerciseMode(mode)
                sessionSeconds = 0
                isTimerRunning = false
            }
            .onChange(of: router.requestedExerciseRaw) { _, raw in
                guard let name = raw?.lowercased() else { return }
                if let matched = ExerciseMode.allCases.first(where: { $0.rawValue.lowercased().contains(name) }) {
                    selectedExercise = matched
                }
                router.requestedExerciseRaw = nil
            }
            .onDisappear {
                poseController.stop()
                isTimerRunning = false
            }
        }
    }

    // MARK: - Dynamic Island Rest Countdown Banner
    private var restCountdownPill: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "timer")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ApexTheme.standCyan)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Recovery Rest Timer")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Lock Screen & Dynamic Island active")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(formatDuration(activityMgr.restSecondsRemaining))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ApexTheme.standCyan)

            Button {
                Haptics.tap()
                activityMgr.stopRestTimer()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
        }
        .appleCard(padding: 14, cornerRadius: 18)
    }

    // MARK: - Horizontal Capsule Exercise Selector
    private var exerciseSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ExerciseMode.allCases) { mode in
                    let isSelected = selectedExercise == mode
                    Button {
                        Haptics.tap()
                        selectedExercise = mode
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isSelected ? .black : .white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(isSelected ? ApexTheme.accentVolt : ApexTheme.cardSurface)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(isSelected ? Color.clear : ApexTheme.subtleBorder, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Optical Camera Viewfinder Card
    private var viewfinderHero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(ApexTheme.cardSurface)

            if poseController.isCameraRunning {
                ZStack {
                    PoseCameraPreview(session: poseController.session)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                    PoseSkeletonCanvas(
                        joints: poseController.detectedJoints,
                        wristPathTrace: poseController.wristPathTrace
                    )
                }
            } else {
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(ApexTheme.exerciseLime.opacity(0.14))
                            .frame(width: 72, height: 72)
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(ApexTheme.exerciseLime)
                    }

                    VStack(spacing: 4) {
                        Text(selectedExercise.rawValue)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                        Text(poseController.cameraAvailable
                             ? "Tracks joint angles, eccentric tempo, form symmetry, and velocity loss % automatically."
                             : "Use the stopwatch & rep controls on Simulator, or open on iPhone for live camera pose tracking.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.vertical, 32)
            }

            // Top HUD Overlay
            VStack {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(poseController.isCameraRunning ? ApexTheme.exerciseLime : .gray)
                            .frame(width: 7, height: 7)
                        Text(poseController.isCameraRunning ? "Optical Pose Active" : "Ready")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())

                    Spacer()

                    Text(formatDuration(sessionSeconds))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }

                Spacer()

                VStack(spacing: 6) {
                    if let faultCue = poseController.formFaultCue {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                            Text(faultCue)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(ApexTheme.accentAmber)
                        .clipShape(Capsule())
                    }

                    Text(poseController.guidanceCue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }
            .padding(14)
        }
        .frame(height: 330)
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(ApexTheme.subtleBorder, lineWidth: 0.5)
        )
    }

    // MARK: - Live Kinematics & Tempo Readout Bar
    private var kinematicMetricsBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("REPS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("\(poseController.repCount)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(ApexTheme.accentVolt)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .appleCard(padding: 14, cornerRadius: 18)

                VStack(alignment: .leading, spacing: 4) {
                    Text("VELOCITY")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.2f", poseController.concentricVelocity))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                        Text("m/s")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .appleCard(padding: 14, cornerRadius: 18)

                VStack(alignment: .leading, spacing: 4) {
                    Text("VBT DROP")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("-\(poseController.velocityLossPercent)%")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(poseController.velocityLossPercent >= 20 ? ApexTheme.accentAmber : ApexTheme.standCyan)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .appleCard(padding: 14, cornerRadius: 18)
            }

            // Secondary Tempo, Power, 3D Depth & BLE Heart Rate Row
            HStack(spacing: 8) {
                Label("\(poseController.jointAngle)°", systemImage: "angle")
                Spacer()
                Label(String(format: "%.1fs ecc", poseController.lastEccentricSeconds), systemImage: "arrow.down.circle")
                Spacer()
                let powerSuffix = poseController.estimated1RMPercent > 0 ? "· \(poseController.estimated1RMPercent)%" : "· BW"
                Label("\(poseController.estimatedPowerWatts)W \(powerSuffix)", systemImage: "bolt")
                if let bpm = bleHR.liveBPM {
                    Spacer()
                    Label("\(bpm)", systemImage: "heart.fill")
                        .foregroundStyle(ApexTheme.moveCrimson)
                } else if poseController.is3DPoseActive {
                    Spacer()
                    Label("3D", systemImage: "cube.transparent")
                        .foregroundStyle(ApexTheme.standCyan)
                }
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .appleCard(padding: 12, cornerRadius: 14)

            // User Load & Athlete Height Calibration Bar
            HStack(spacing: 12) {
                if selectedExercise.isBodyweight {
                    Label("Bodyweight Load (\(Int((health.bodyWeightKg ?? 75.0).rounded())) kg)", systemImage: "figure.strengthtraining.functional")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    HStack(spacing: 8) {
                        Button {
                            Haptics.tap()
                            externalLoadKg = max(5, externalLoadKg - 2.5)
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        }
                        Text("\(String(format: "%.1f", externalLoadKg).replacingOccurrences(of: ".0", with: "")) kg bar")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                        Button {
                            Haptics.tap()
                            externalLoadKg = min(350, externalLoadKg + 2.5)
                        } label: {
                            Image(systemName: "plus.circle.fill").foregroundStyle(ApexTheme.accentVolt)
                        }
                    }
                    Spacer()
                }

                HStack(spacing: 6) {
                    Button {
                        Haptics.tap()
                        athleteHeightCm = max(135, athleteHeightCm - 1)
                    } label: {
                        Image(systemName: "minus.circle").foregroundStyle(.secondary)
                    }
                    Text("\(Int(athleteHeightCm))cm")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Button {
                        Haptics.tap()
                        athleteHeightCm = min(220, athleteHeightCm + 1)
                    } label: {
                        Image(systemName: "plus.circle").foregroundStyle(.secondary)
                    }
                }
            }
            .appleCard(padding: 12, cornerRadius: 14)
        }
    }

    // MARK: - Active Set & Logging Controls
    private var sessionControls: some View {
        VStack(spacing: 12) {
            if let banner = savedBanner {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ApexTheme.accentEmerald)
                    Text(banner)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .appleCard(padding: 12, cornerRadius: 14)
            }

            HStack(spacing: 12) {
                Button {
                    Haptics.tap(.medium)
                    if poseController.cameraAvailable {
                        if poseController.isCameraRunning {
                            poseController.stop()
                            isTimerRunning = false
                        } else {
                            poseController.setExerciseMode(selectedExercise)
                            poseController.start()
                            isTimerRunning = true
                            activityMgr.startSet(exercise: selectedExercise.rawValue)
                        }
                    } else {
                        isTimerRunning.toggle()
                        if isTimerRunning && sessionSeconds == 0 {
                            activityMgr.startSet(exercise: selectedExercise.rawValue)
                        }
                    }
                } label: {
                    let isActive = poseController.isCameraRunning || isTimerRunning
                    HStack(spacing: 8) {
                        Image(systemName: isActive ? "pause.fill" : (poseController.cameraAvailable ? "video.fill" : "play.fill"))
                        Text(isActive ? "Pause Set" : (poseController.cameraAvailable ? "Start Camera Set" : "Start Set Timer"))
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isActive ? ApexTheme.accentAmber : ApexTheme.accentVolt)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                HStack(spacing: 10) {
                    Button {
                        Haptics.tap()
                        poseController.adjustReps(-1)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 44, height: 48)
                            .background(ApexTheme.elevatedSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Button {
                        Haptics.tap(.medium)
                        poseController.adjustReps(1)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 44, height: 48)
                            .background(ApexTheme.elevatedSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .foregroundStyle(.white)
            }

            Button {
                saveWorkoutToHealth()
            } label: {
                HStack(spacing: 8) {
                    if isSavingWorkout {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(ApexTheme.moveCrimson)
                        Text("Complete Set & Log to Health")
                    }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ApexTheme.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(ApexTheme.subtleBorder, lineWidth: 0.5)
                )
            }
            .disabled(isSavingWorkout || (poseController.repCount == 0 && sessionSeconds < 5))
            .opacity((poseController.repCount == 0 && sessionSeconds < 5) ? 0.5 : 1.0)
        }
    }

    // MARK: - Completed Sets History
    private var completedSetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Completed Sets")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            VStack(spacing: 10) {
                ForEach(workoutHistory) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(entry.exercise) · \(entry.reps) reps")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            let vbtText = (entry.velocityLossPercent ?? 0) > 0 ? " · -\(entry.velocityLossPercent!)% VBT" : ""
                            Text("\(formatDuration(entry.durationSeconds)) · \(String(format: "%.1f kcal", entry.calories))\(vbtText)")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(entry.date.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .appleCard(padding: 14, cornerRadius: 16)
                }
            }
        }
    }

    // MARK: - Commit Set to Apple HealthKit + Start Rest Timer + Sync to Mac
    private func saveWorkoutToHealth() {
        let reps = max(1, poseController.repCount)
        let secs = max(10, sessionSeconds)
        let kcal = Double(reps) * selectedExercise.kcalPerRep + Double(secs) * 0.08
        let peakVel = poseController.peakVelocity
        let velDrop = poseController.velocityLossPercent

        Haptics.tap(.medium)
        isSavingWorkout = true
        poseController.stop()
        isTimerRunning = false

        Task {
            let committed = await health.logWorkout(
                calories: kcal,
                durationMinutes: Double(secs) / 60.0,
                workoutType: selectedExercise.workoutType
            )

            let entry = WorkoutSetEntry(
                id: UUID(),
                exercise: selectedExercise.rawValue,
                reps: reps,
                durationSeconds: secs,
                calories: kcal,
                peakVelocity: peakVel,
                velocityLossPercent: velDrop,
                date: Date()
            )
            workoutHistory.insert(entry, at: 0)
            WorkoutSetStore.save(workoutHistory)

            health.syncEventToMac(extraPayload: [
                "workoutSet": [
                    "id": entry.id.uuidString,
                    "exercise": entry.exercise,
                    "reps": entry.reps,
                    "durationSeconds": entry.durationSeconds,
                    "calories": entry.calories,
                    "peakVelocity": peakVel,
                    "velocityLossPercent": velDrop,
                    "date": ISO8601DateFormatter().string(from: entry.date)
                ]
            ])

            activityMgr.startRestCountdown(seconds: 90, reps: reps, elapsedSeconds: secs)

            isSavingWorkout = false
            savedBanner = committed
                ? "Logged \(reps) \(selectedExercise.rawValue) · 90s rest started"
                : "Saved \(reps) reps locally · 90s rest started"
            poseController.reset()
            sessionSeconds = 0
            Haptics.success()

            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                savedBanner = nil
            }
        }
    }

    private func formatDuration(_ sec: Int) -> String {
        String(format: "%d:%02d", sec / 60, sec % 60)
    }
}

// MARK: - SwiftUI Optical Skeleton & Bar Path Trace Canvas
private struct PoseSkeletonCanvas: View {
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    let wristPathTrace: [CGPoint]

    private let bonePairs: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
        (.leftHip, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle)
    ]

    var body: some View {
        Canvas { ctx, size in
            func map(_ p: CGPoint) -> CGPoint {
                CGPoint(x: p.x * size.width, y: p.y * size.height)
            }

            if wristPathTrace.count >= 2 {
                var barPath = Path()
                barPath.move(to: map(wristPathTrace[0]))
                for pt in wristPathTrace.dropFirst() {
                    barPath.addLine(to: map(pt))
                }
                ctx.stroke(
                    barPath,
                    with: .color(ApexTheme.accentVolt.opacity(0.65)),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                )
            }

            for (a, b) in bonePairs {
                if let p1 = joints[a], let p2 = joints[b] {
                    var path = Path()
                    path.move(to: map(p1))
                    path.addLine(to: map(p2))
                    ctx.stroke(path, with: .color(ApexTheme.standCyan.opacity(0.85)), lineWidth: 2.5)
                }
            }

            for (_, pt) in joints {
                let p = map(pt)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)), with: .color(ApexTheme.accentVolt))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Live AVFoundation Camera + Apple Vision 2D/3D Body Pose & VBT Engine
private class BodyPoseController: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var isCameraRunning: Bool = false
    @Published var repCount: Int = 0
    @Published var jointAngle: Int = 175
    @Published var concentricVelocity: Double = 0.0
    @Published var peakVelocity: Double = 0.0
    @Published var velocityLossPercent: Int = 0
    @Published var lastEccentricSeconds: Double = 0.0
    @Published var estimatedPowerWatts: Int = 0
    @Published var estimated1RMPercent: Int = 0
    @Published var is3DPoseActive: Bool = false
    @Published var wristPathTrace: [CGPoint] = []
    @Published var guidanceCue: String = "Position full body in frame"
    @Published var formFaultCue: String? = nil
    @Published var detectedJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]

    var voiceCoachingEnabled: Bool = true
    var externalLoadKg: Double = 60.0
    var athleteHeightCm: Double = 175.0
    var bodyWeightKg: Double = 75.0
    let cameraAvailable: Bool
    let session = AVCaptureSession()

    private let poseQueue = DispatchQueue(label: "apex.body.pose.queue", qos: .userInteractive)
    private let synthesizer = AVSpeechSynthesizer()
    private var exerciseMode: CameraWorkoutView.ExerciseMode = .squats
    private var repPhase: String = "UP"
    private var eccentricStartTime: Date = Date()
    private var concentricStartTime: Date = Date()
    private var baselineRepPeakVelocity: Double = 0.0
    private var tracked3DMinY: Double? = nil
    private var tracked3DMaxY: Double? = nil
    private var latest3DRomMeters: Double? = nil
    private var frameCounter: Int = 0
    private var isConfigured = false

    override init() {
        self.cameraAvailable = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
        super.init()
    }

    func setExerciseMode(_ mode: CameraWorkoutView.ExerciseMode) {
        exerciseMode = mode
        reset()
        guidanceCue = "Ready for \(mode.rawValue)"
    }

    func adjustReps(_ delta: Int) {
        repCount = max(0, repCount + delta)
    }

    func reset() {
        repCount = 0
        jointAngle = 175
        concentricVelocity = 0.0
        peakVelocity = 0.0
        velocityLossPercent = 0
        baselineRepPeakVelocity = 0.0
        lastEccentricSeconds = 0.0
        estimatedPowerWatts = 0
        estimated1RMPercent = 0
        wristPathTrace = []
        is3DPoseActive = false
        formFaultCue = nil
        repPhase = "UP"
    }

    func start() {
        guard cameraAvailable else { return }
        if session.isRunning {
            DispatchQueue.main.async { self.isCameraRunning = true }
            return
        }

        poseQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.isConfigured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .high

                if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                   let input = try? AVCaptureDeviceInput(device: device),
                   self.session.canAddInput(input) {
                    self.session.addInput(input)
                }

                let output = AVCaptureVideoDataOutput()
                output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                output.alwaysDiscardsLateVideoFrames = true
                output.setSampleBufferDelegate(self, queue: self.poseQueue)
                if self.session.canAddOutput(output) {
                    self.session.addOutput(output)
                }
                if let conn = output.connection(with: .video) {
                    if conn.isVideoRotationAngleSupported(90) {
                        conn.videoRotationAngle = 90
                    }
                    if conn.isVideoMirroringSupported {
                        conn.isVideoMirrored = true
                    }
                }
                self.session.commitConfiguration()
                self.isConfigured = true
            }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isCameraRunning = true
                self.guidanceCue = "Tracking skeleton · Begin rep"
            }
        }
    }

    func stop() {
        guard session.isRunning else {
            DispatchQueue.main.async { self.isCameraRunning = false }
            return
        }
        poseQueue.async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async {
                self?.isCameraRunning = false
                self?.detectedJoints = [:]
                self?.wristPathTrace = []
                self?.is3DPoseActive = false
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        frameCounter += 1
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([request])

        var found3D = false
        var sample3DY: Double? = nil
        if #available(iOS 17.0, *), frameCounter % 3 == 0 {
            let req3D = VNDetectHumanBodyPose3DRequest()
            try? handler.perform([req3D])
            if let obs3D = req3D.results?.first, obs3D.bodyHeight > 0.5,
               let pts3D = try? obs3D.recognizedPoints(.all) {
                found3D = true
                let jointKey: VNHumanBodyPose3DObservation.JointName = {
                    switch exerciseMode {
                    case .squats, .lunges, .rdl: return .root
                    default: return .rightWrist
                    }
                }()
                if let pt = pts3D[jointKey] ?? pts3D[.centerShoulder] {
                    sample3DY = Double(pt.localPosition.columns.3.y)
                }
            }
        }

        guard let obs = request.results?.first,
              let recognized = try? obs.recognizedPoints(.all) else {
            return
        }

        var mapped: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        for (name, pt) in recognized where pt.confidence > 0.35 {
            mapped[name] = CGPoint(x: pt.location.x, y: 1.0 - pt.location.y)
        }

        DispatchQueue.main.async {
            if found3D {
                self.is3DPoseActive = true
                if let y3d = sample3DY {
                    self.tracked3DMinY = min(self.tracked3DMinY ?? y3d, y3d)
                    self.tracked3DMaxY = max(self.tracked3DMaxY ?? y3d, y3d)
                    if let lo = self.tracked3DMinY, let hi = self.tracked3DMaxY {
                        let span = hi - lo
                        if span >= 0.14 && span <= 1.25 {
                            self.latest3DRomMeters = span
                        }
                    }
                }
            }
            self.detectedJoints = mapped
            self.evaluateKinematics(mapped)
        }
    }

    private func evaluateKinematics(_ joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) {
        // Track dominant wrist/shoulder anchor for bar-path trajectory trace
        let tracePoint: CGPoint? = {
            switch exerciseMode {
            case .squats, .lunges, .rdl:
                return joints[.leftHip] ?? joints[.rightHip] ?? joints[.leftShoulder]
            default:
                return joints[.rightWrist] ?? joints[.leftWrist]
            }
        }()
        if let pt = tracePoint {
            wristPathTrace.append(pt)
            if wristPathTrace.count > 28 {
                wristPathTrace.removeFirst(wristPathTrace.count - 28)
            }
        }

        // Check horizontal shoulder balance for bilateral form warning
        if let ls = joints[.leftShoulder], let rs = joints[.rightShoulder] {
            let shoulderTilt = abs(ls.y - rs.y)
            formFaultCue = shoulderTilt > 0.085 ? "Level Left/Right Shoulders" : nil
        }

        switch exerciseMode {
        case .squats, .lunges:
            let hip = joints[.leftHip] ?? joints[.rightHip]
            let knee = joints[.leftKnee] ?? joints[.rightKnee]
            let ankle = joints[.leftAnkle] ?? joints[.rightAnkle]
            if let h = hip, let k = knee, let a = ankle {
                let angle = Self.angleBetween(p1: h, vertex: k, p2: a)
                jointAngle = angle
                processCycle(angle: angle, downThreshold: 102, upThreshold: 156, cueDown: "Parallel depth hit — drive up")
            }

        case .rdl:
            let shoulder = joints[.leftShoulder] ?? joints[.rightShoulder]
            let hip = joints[.leftHip] ?? joints[.rightHip]
            let knee = joints[.leftKnee] ?? joints[.rightKnee]
            if let s = shoulder, let h = hip, let k = knee {
                let angle = Self.angleBetween(p1: s, vertex: h, p2: k)
                jointAngle = angle
                processCycle(angle: angle, downThreshold: 105, upThreshold: 162, cueDown: "Hip hinge loaded — lock glutes")
            }

        case .pushups, .curls, .pullups, .ohp:
            let shoulder = joints[.leftShoulder] ?? joints[.rightShoulder]
            let elbow = joints[.leftElbow] ?? joints[.rightElbow]
            let wrist = joints[.leftWrist] ?? joints[.rightWrist]
            if let s = shoulder, let e = elbow, let w = wrist {
                let angle = Self.angleBetween(p1: s, vertex: e, p2: w)
                jointAngle = angle
                let isInvertedPhase = (exerciseMode == .pullups || exerciseMode == .ohp)
                if isInvertedPhase {
                    processCycle(angle: angle, downThreshold: 80, upThreshold: 155, cueDown: "Strong pull/lockout — lower slow")
                } else {
                    let down = exerciseMode == .pushups ? 95 : 65
                    processCycle(angle: angle, downThreshold: down, upThreshold: 150, cueDown: "Good range — extend smoothly")
                }
            }

        case .jacks:
            if let lw = joints[.leftWrist], let rw = joints[.rightWrist], let ls = joints[.leftShoulder] {
                let wristsHigh = lw.y < ls.y && rw.y < ls.y
                jointAngle = wristsHigh ? 175 : 25
                if wristsHigh && repPhase == "UP" {
                    repPhase = "DOWN"
                    concentricStartTime = Date()
                    guidanceCue = "Hands overhead — snap down"
                } else if !wristsHigh && repPhase == "DOWN" {
                    completeRep()
                }
            }
        }
    }

    private func processCycle(angle: Int, downThreshold: Int, upThreshold: Int, cueDown: String) {
        if angle <= downThreshold && repPhase == "UP" {
            let eccentric = Date().timeIntervalSince(eccentricStartTime)
            lastEccentricSeconds = min(6.0, max(0.3, (eccentric * 10).rounded() / 10))
            repPhase = "DOWN"
            concentricStartTime = Date()
            guidanceCue = cueDown
        } else if angle >= upThreshold && repPhase == "DOWN" {
            completeRep()
            eccentricStartTime = Date()
        }
    }

    private func completeRep() {
        repPhase = "UP"
        let dt = max(0.32, Date().timeIntervalSince(concentricStartTime))
        let heightScale = max(0.75, min(1.30, athleteHeightCm / 175.0))
        let romMeters = latest3DRomMeters ?? (exerciseMode.baselineRomMeters * heightScale)
        tracked3DMinY = nil
        tracked3DMaxY = nil
        latest3DRomMeters = nil

        let vel = min(2.10, ((romMeters / dt) * 100).rounded() / 100)
        concentricVelocity = vel
        if vel > peakVelocity {
            peakVelocity = vel
        }
        if baselineRepPeakVelocity == 0 {
            baselineRepPeakVelocity = vel
        } else if vel > baselineRepPeakVelocity && repCount <= 2 {
            baselineRepPeakVelocity = vel
        }

        if baselineRepPeakVelocity > 0.1 {
            let loss = max(0, Int(((baselineRepPeakVelocity - vel) / baselineRepPeakVelocity * 100.0).rounded()))
            velocityLossPercent = min(65, loss)
        }

        // Gonzalez-Badillo velocity-to-%1RM load-velocity profile (barbell loads) + real load/bodyweight power (Watts)
        let pct1RM = max(45, min(98, Int(((1.45 - vel) / 1.15 * 100.0).rounded())))
        estimated1RMPercent = exerciseMode.isBodyweight ? 0 : pct1RM
        let massKg = exerciseMode.isBodyweight ? max(40.0, bodyWeightKg) : max(5.0, externalLoadKg)
        estimatedPowerWatts = Int((massKg * 9.81 * vel).rounded())

        repCount += 1
        if velocityLossPercent >= 20 {
            guidanceCue = "Rep \(repCount) · Fatigue -\(velocityLossPercent)% (Optimal Stop)"
        } else {
            guidanceCue = "Rep \(repCount) · \(String(format: "%.2f m/s", vel))"
        }
        Haptics.tap(.medium)

        if voiceCoachingEnabled {
            let spoken = velocityLossPercent >= 20 ? "\(repCount), velocity drop" : "\(repCount)"
            let utterance = AVSpeechUtterance(string: spoken)
            utterance.rate = 0.54
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            synthesizer.speak(utterance)
        }
    }

    private static func angleBetween(p1: CGPoint, vertex: CGPoint, p2: CGPoint) -> Int {
        let v1 = CGVector(dx: p1.x - vertex.x, dy: p1.y - vertex.y)
        let v2 = CGVector(dx: p2.x - vertex.x, dy: p2.y - vertex.y)
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let mag1 = hypot(v1.dx, v1.dy)
        let mag2 = hypot(v2.dx, v2.dy)
        guard mag1 > 0, mag2 > 0 else { return 180 }
        let cosAngle = max(-1.0, min(1.0, Double(dot / (mag1 * mag2))))
        return Int((acos(cosAngle) * 180.0 / .pi).rounded())
    }
}

private struct PoseCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PosePreviewContainer {
        let view = PosePreviewContainer()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PosePreviewContainer, context: Context) {}
}

private final class PosePreviewContainer: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

private enum WorkoutSetStore {
    private static let key = "apex_ios_workout_sets_v1"

    static func load() -> [WorkoutSetEntry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([WorkoutSetEntry].self, from: data) else {
            return []
        }
        return decoded
    }

    static func save(_ entries: [WorkoutSetEntry]) {
        if let encoded = try? JSONEncoder().encode(Array(entries.prefix(25))) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
}
