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
    public let date: Date
}

// MARK: - Native Apple Vision Optical Pose & Strength Tracker
public struct CameraWorkoutView: View {
    @ObservedObject private var health = HealthKitManager.shared
    @StateObject private var poseController = BodyPoseController()

    @State private var selectedExercise: ExerciseMode = .squats
    @State private var isVoiceEnabled: Bool = true
    @State private var isSavingWorkout: Bool = false
    @State private var savedBanner: String? = nil

    // Live Workout Timer
    @State private var sessionSeconds: Int = 0
    @State private var isTimerRunning: Bool = false
    @State private var workoutHistory: [WorkoutSetEntry] = WorkoutSetStore.load()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public enum ExerciseMode: String, CaseIterable, Identifiable {
        case squats = "Squats"
        case pushups = "Push-ups"
        case curls = "Bicep Curls"
        case jacks = "Jumping Jacks"

        public var id: String { rawValue }

        var kcalPerRep: Double {
            switch self {
            case .squats: return 0.65
            case .pushups: return 0.50
            case .curls: return 0.35
            case .jacks: return 0.45
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
                    // 1. HORIZONTAL EXERCISE SELECTOR (Never wraps or cramps)
                    exerciseSelector

                    // 2. LIVE VISION VIEWFINDER OR SESSION STOPWATCH
                    viewfinderHero

                    // 3. REAL-TIME KINEMATICS METRICS (ROM & VELOCITY)
                    kinematicMetricsBar

                    // 4. ACTIVE SET CONTROLS (Save real set to Apple Health)
                    sessionControls

                    // 5. COMPLETED SETS LOG
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
            .onReceive(timer) { _ in
                if isTimerRunning {
                    sessionSeconds += 1
                }
            }
            .onChange(of: selectedExercise) { _, mode in
                poseController.setExerciseMode(mode)
                sessionSeconds = 0
                isTimerRunning = false
            }
            .onDisappear {
                poseController.stop()
                isTimerRunning = false
            }
        }
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

                    PoseSkeletonCanvas(joints: poseController.detectedJoints)
                }
            } else {
                // Editorial Standby State
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(ApexTheme.moveCrimson.opacity(0.14))
                            .frame(width: 72, height: 72)
                        Image(systemName: poseController.cameraAvailable ? "figure.strengthtraining.traditional" : "stopwatch.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(ApexTheme.moveCrimson)
                    }

                    VStack(spacing: 4) {
                        Text(poseController.cameraAvailable ? "Optical Pose Coaching" : "Strength Session Ready")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(poseController.cameraAvailable
                             ? "Position your iPhone upright to count \(selectedExercise.rawValue.lowercased()) automatically via Apple Vision."
                             : "Front camera available on physical iPhone. Track your set duration & reps cleanly below.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
            }

            // Frosted HUD Overlay
            VStack {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(poseController.isCameraRunning ? ApexTheme.accentEmerald : (isTimerRunning ? ApexTheme.accentVolt : .gray))
                            .frame(width: 7, height: 7)
                        Text(poseController.isCameraRunning ? "Vision Active" : (isTimerRunning ? "Set Active" : "Ready"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())

                    Spacer()

                    Text(formatDuration(sessionSeconds))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
                .padding(14)

                Spacer()

                // Prominent Rounded Rep Counter
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("REPS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text("\(poseController.repCount)")
                            .font(.system(size: 58, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(ApexTheme.accentVolt)
                            .contentTransition(.numericText())
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Spacer()

                    // Manual Adjust +/- for weighted sets
                    HStack(spacing: 8) {
                        Button {
                            Haptics.tap()
                            poseController.adjustReps(-1)
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }

                        Button {
                            Haptics.tap(.medium)
                            if !isTimerRunning { isTimerRunning = true }
                            poseController.adjustReps(1)
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(width: 38, height: 38)
                                .background(ApexTheme.accentVolt)
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 14)

                // Guidance Capsule
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ApexTheme.standCyan)
                    Text(poseController.guidanceCue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(14)
            }
        }
        .frame(height: 350)
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(ApexTheme.subtleBorder, lineWidth: 0.5)
        )
    }

    // MARK: - Kinematics Bar (ROM + Velocity)
    private var kinematicMetricsBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Joint Angle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("\(poseController.jointAngle)°")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appleCard(padding: 14, cornerRadius: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text("Peak Velocity")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(String(format: "%.2f m/s", poseController.concentricVelocity))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ApexTheme.standCyan)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appleCard(padding: 14, cornerRadius: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text("Est. Energy")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("\(Int((Double(poseController.repCount) * selectedExercise.kcalPerRep).rounded())) kcal")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ApexTheme.moveCrimson)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appleCard(padding: 14, cornerRadius: 18)
        }
    }

    // MARK: - Camera & Save Set Action Bar
    private var sessionControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                if poseController.cameraAvailable {
                    Button {
                        Haptics.tap()
                        if poseController.isCameraRunning {
                            poseController.stop()
                        } else {
                            poseController.start()
                            isTimerRunning = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: poseController.isCameraRunning ? "video.slash.fill" : "video.fill")
                            Text(poseController.isCameraRunning ? "Stop Camera" : "Start Camera")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ApexTheme.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                } else {
                    Button {
                        Haptics.tap()
                        isTimerRunning.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                            Text(isTimerRunning ? "Pause Set" : "Start Set Timer")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ApexTheme.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                Button {
                    saveWorkoutToHealth()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isSavingWorkout ? "hourglass" : "checkmark.circle.fill")
                        Text(isSavingWorkout ? "Saving..." : "Log to Health")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(poseController.repCount > 0 || sessionSeconds > 0 ? ApexTheme.accentVolt : ApexTheme.accentVolt.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(isSavingWorkout || (poseController.repCount == 0 && sessionSeconds == 0))
            }

            if let banner = savedBanner {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(ApexTheme.accentEmerald)
                    Text(banner)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(ApexTheme.accentEmerald.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
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
                            Text("\(formatDuration(entry.durationSeconds)) · \(Int(entry.calories.rounded())) kcal · \(entry.date.formatted(date: .omitted, time: .shortened))")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(ApexTheme.moveCrimson)
                    }
                    .appleCard(padding: 14, cornerRadius: 16)
                }
            }
        }
    }

    private func saveWorkoutToHealth() {
        let reps = max(1, poseController.repCount)
        let durationSec = max(15, sessionSeconds)
        let durationMin = max(0.5, Double(durationSec) / 60.0)
        let kcal = max(5.0, Double(reps) * selectedExercise.kcalPerRep + durationMin * 3.5)

        isSavingWorkout = true
        Haptics.tap(.medium)

        Task {
            let syncedHealth = await health.logWorkout(
                calories: kcal,
                durationMinutes: durationMin,
                workoutType: selectedExercise.workoutType
            )

            let record = WorkoutSetEntry(
                id: UUID(),
                exercise: selectedExercise.rawValue,
                reps: reps,
                durationSeconds: durationSec,
                calories: kcal,
                date: Date()
            )

            await MainActor.run {
                workoutHistory.insert(record, at: 0)
                WorkoutSetStore.save(workoutHistory)
                poseController.reset()
                sessionSeconds = 0
                isTimerRunning = false
                isSavingWorkout = false
                savedBanner = syncedHealth
                    ? "Saved \(reps) \(selectedExercise.rawValue) (+\(Int(kcal)) kcal) to Apple Health"
                    : "Set logged (+\(Int(kcal)) kcal)"
                Haptics.success()

                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    savedBanner = nil
                }
            }
        }
    }

    private func formatDuration(_ sec: Int) -> String {
        let m = sec / 60
        let s = sec % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Skeleton Vector Overlay Canvas
private struct PoseSkeletonCanvas: View {
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]

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

            for (a, b) in bonePairs {
                if let ptA = joints[a], let ptB = joints[b] {
                    var path = Path()
                    path.move(to: map(ptA))
                    path.addLine(to: map(ptB))
                    ctx.stroke(path, with: .color(ApexTheme.standCyan.opacity(0.85)), lineWidth: 3)
                }
            }

            for pt in joints.values {
                let p = map(pt)
                let rect = CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9)
                ctx.fill(Path(ellipseIn: rect), with: .color(ApexTheme.accentVolt))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Live AVFoundation Camera + Apple Vision Body Pose Engine
private class BodyPoseController: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var isCameraRunning: Bool = false
    @Published var repCount: Int = 0
    @Published var jointAngle: Int = 175
    @Published var concentricVelocity: Double = 0.0
    @Published var guidanceCue: String = "Stand in frame to track form"
    @Published var detectedJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]

    var voiceCoachingEnabled: Bool = true
    let cameraAvailable: Bool
    let session = AVCaptureSession()

    private let poseQueue = DispatchQueue(label: "apex.body.pose.queue", qos: .userInteractive)
    private let synthesizer = AVSpeechSynthesizer()
    private var exerciseMode: CameraWorkoutView.ExerciseMode = .squats
    private var repPhase: String = "UP"
    private var phaseStartTime: Date = Date()
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
                self.guidanceCue = "Tracking skeleton · Start set"
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
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([request])

        guard let obs = request.results?.first,
              let recognized = try? obs.recognizedPoints(.all) else {
            return
        }

        var mapped: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        for (name, pt) in recognized where pt.confidence > 0.35 {
            // Vision origin is bottom-left; SwiftUI Canvas origin is top-left
            mapped[name] = CGPoint(x: pt.location.x, y: 1.0 - pt.location.y)
        }

        DispatchQueue.main.async {
            self.detectedJoints = mapped
            self.evaluateKinematics(mapped)
        }
    }

    private func evaluateKinematics(_ joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) {
        switch exerciseMode {
        case .squats:
            let hip = joints[.leftHip] ?? joints[.rightHip]
            let knee = joints[.leftKnee] ?? joints[.rightKnee]
            let ankle = joints[.leftAnkle] ?? joints[.rightAnkle]
            if let h = hip, let k = knee, let a = ankle {
                let angle = Self.angleBetween(p1: h, vertex: k, p2: a)
                jointAngle = angle
                processCycle(angle: angle, downThreshold: 100, upThreshold: 155, cueDown: "Depth achieved — drive up")
            }

        case .pushups, .curls:
            let shoulder = joints[.leftShoulder] ?? joints[.rightShoulder]
            let elbow = joints[.leftElbow] ?? joints[.rightElbow]
            let wrist = joints[.leftWrist] ?? joints[.rightWrist]
            if let s = shoulder, let e = elbow, let w = wrist {
                let angle = Self.angleBetween(p1: s, vertex: e, p2: w)
                jointAngle = angle
                let down = exerciseMode == .pushups ? 95 : 65
                let up = 150
                processCycle(angle: angle, downThreshold: down, upThreshold: up, cueDown: "Good flexion — extend cleanly")
            }

        case .jacks:
            if let lw = joints[.leftWrist], let rw = joints[.rightWrist], let ls = joints[.leftShoulder] {
                let wristsHigh = lw.y < ls.y && rw.y < ls.y
                jointAngle = wristsHigh ? 175 : 25
                if wristsHigh && repPhase == "UP" {
                    repPhase = "DOWN"
                    phaseStartTime = Date()
                    guidanceCue = "Hands up — return cleanly"
                } else if !wristsHigh && repPhase == "DOWN" {
                    completeRep()
                }
            }
        }
    }

    private func processCycle(angle: Int, downThreshold: Int, upThreshold: Int, cueDown: String) {
        if angle <= downThreshold && repPhase == "UP" {
            repPhase = "DOWN"
            phaseStartTime = Date()
            guidanceCue = cueDown
        } else if angle >= upThreshold && repPhase == "DOWN" {
            completeRep()
        }
    }

    private func completeRep() {
        repPhase = "UP"
        let dt = max(0.35, Date().timeIntervalSince(phaseStartTime))
        concentricVelocity = min(1.85, (0.55 / dt * 100).rounded() / 100)
        repCount += 1
        guidanceCue = "Rep \(repCount) locked · \(String(format: "%.2f m/s", concentricVelocity))"
        Haptics.tap(.medium)

        if voiceCoachingEnabled {
            let utterance = AVSpeechUtterance(string: "\(repCount)")
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
        if let encoded = try? JSONEncoder().encode(Array(entries.prefix(20))) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
}
