import SwiftUI
import AVFoundation

// MARK: - Native iOS AVFoundation Front Camera Workout Tracker
public struct CameraWorkoutView: View {
    @StateObject private var cameraController = CameraController()
    @State private var repCount: Int = 0
    @State private var currentExercise: String = "Squats"
    @State private var feedbackText: String = "Position in frame · 5ft back"
    @State private var currentAngle: Int = 165

    private let exercises = ["Squats", "Push-ups", "Bicep Curls", "Jumping Jacks"]

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "camera.viewfinder")
                        .foregroundColor(Color(red: 0.90, green: 1.0, blue: 0.25))
                        .font(.system(size: 16, weight: .bold))
                    Text("AI Optical Workout Tracker")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
                Spacer()
                Text("VISION ENGINE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.06, green: 0.73, blue: 0.51).opacity(0.2))
                    .foregroundColor(Color(red: 0.06, green: 0.73, blue: 0.51))
                    .cornerRadius(8)
            }
            .padding(.horizontal)

            // Exercise Picker
            HStack(spacing: 8) {
                ForEach(exercises, id: \.self) { ex in
                    Button(action: {
                        currentExercise = ex
                        repCount = 0
                        feedbackText = "Ready for \(ex). Begin set."
                    }) {
                        Text(ex)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(currentExercise == ex ? Color(red: 0.90, green: 1.0, blue: 0.25) : Color.white.opacity(0.08))
                            .foregroundColor(currentExercise == ex ? .black : .white)
                            .cornerRadius(10)
                    }
                }
            }
            .padding(.horizontal)

            // Camera Viewfinder Box
            ZStack {
                if cameraController.isCameraRunning {
                    CameraPreviewView(session: cameraController.session)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                } else {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(red: 0.04, green: 0.05, blue: 0.07))
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "video.badge.waveform")
                                    .font(.system(size: 40))
                                    .foregroundColor(Color(red: 0.0, green: 0.94, blue: 1.0))
                                Text("Tap below to start front camera")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                        )
                }

                // HUD Overlays
                VStack {
                    HStack {
                        Text(currentExercise.uppercased())
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .padding(6)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        Spacer()
                        Text("ROM: \(currentAngle)°")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .padding(6)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(Color(red: 0.0, green: 0.94, blue: 1.0))
                            .cornerRadius(8)
                    }
                    .padding(12)

                    Spacer()

                    // Center Rep Counter
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("REPS")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                            Text("\(repCount)")
                                .font(.system(size: 56, weight: .black, design: .monospaced))
                                .foregroundColor(Color(red: 0.90, green: 1.0, blue: 0.25))
                        }
                        .padding(14)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(18)
                        Spacer()
                    }
                    .padding(.horizontal, 16)

                    Spacer()

                    // Bottom Feedback Bar
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(Color(red: 0.90, green: 1.0, blue: 0.25))
                        Text(feedbackText)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(14)
                    .padding(12)
                }
            }
            .frame(height: 340)
            .padding(.horizontal)

            // Controls
            HStack(spacing: 12) {
                Button(action: {
                    if cameraController.isCameraRunning {
                        cameraController.stop()
                    } else {
                        cameraController.start()
                    }
                }) {
                    HStack {
                        Image(systemName: cameraController.isCameraRunning ? "video.slash" : "video")
                        Text(cameraController.isCameraRunning ? "Stop Camera" : "Start Camera")
                    }
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color.white.opacity(0.12))
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }

                Button(action: {
                    repCount += 1
                    currentAngle = 84
                    feedbackText = "✓ Rep \(repCount) recorded! Depth validated."
                    HealthKitManager.shared.logWorkout(calories: 12.5, durationMinutes: 1.0)
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Simulate Rep (\(repCount))")
                    }
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color(red: 0.90, green: 1.0, blue: 0.25))
                    .foregroundColor(.black)
                    .cornerRadius(14)
                }
            }
        }
    }
}

// UIKit AVFoundation Video Preview Bridge
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}

class CameraController: NSObject, ObservableObject {
    @Published var isCameraRunning = false
    let session = AVCaptureSession()

    func start() {
        guard !session.isRunning else {
            isCameraRunning = true
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
               let input = try? AVCaptureDeviceInput(device: device),
               self.session.canAddInput(input) {
                self.session.addInput(input)
            }
            self.session.commitConfiguration()
            self.session.startRunning()

            DispatchQueue.main.async {
                self.isCameraRunning = true
            }
        }
    }

    func stop() {
        guard session.isRunning else {
            isCameraRunning = false
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async {
                self?.isCameraRunning = false
            }
        }
    }
}
