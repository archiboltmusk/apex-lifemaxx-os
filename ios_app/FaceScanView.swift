import SwiftUI
import AVFoundation
import Vision
import PhotosUI
import ARKit

// MARK: - Scan Mode (Front Symmetry vs 90° Side Profile)
public enum FaceScanAngleMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case front = "Front"
    case sideProfile = "Side Profile"
    public var id: String { rawValue }
}

// MARK: - Craniofacial Biometrics Data Model
public struct FaceScanRecord: Codable, Identifiable {
    public let id: UUID
    public let date: Date
    public let canthalTilt: String
    public let canthalAssessment: String
    public let symmetryPercent: Double
    public let midfaceRatio: Double
    public let fwhrRatio: Double
    public let facialThirds: String
    public let scanAngle: String?
    public let gonialAngleDeg: Double?
    public let forwardProjectionScore: Double?
    public let captureQuality: Double?
    public let depthEngine: String?
}

// MARK: - Detected Landmark Overlay Data (Top-Left Normalized Coordinates 0...1)
public struct DetectedFaceOverlay {
    public let contour: [CGPoint]
    public let leftEye: [CGPoint]
    public let rightEye: [CGPoint]
    public let leftEyebrow: [CGPoint]
    public let rightEyebrow: [CGPoint]
    public let noseCrest: [CGPoint]
    public let outerLips: [CGPoint]
    public let leftPupil: CGPoint?
    public let rightPupil: CGPoint?
    public let boundingBoxTopLeft: CGRect
    public let yawDegrees: Double
    public let rollDegrees: Double
    public let alignmentCue: String
    public let isAligned: Bool
}

// MARK: - Native Apple Vision + TrueDepth Face Morphology Studio
public struct FaceScanView: View {
    @StateObject private var controller = FaceVisionController()
    @ObservedObject private var health = HealthKitManager.shared

    @State private var angleMode: FaceScanAngleMode = .front
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var capturedImage: UIImage? = nil
    @State private var showMeshOverlay: Bool = true
    @State private var autoCaptureOnAlign: Bool = true
    @State private var isAnalyzing: Bool = false
    @State private var noFaceAlert: String? = nil
    @State private var showCompareSheet: Bool = false
    @State private var showTrueDepthSheet: Bool = false
    @State private var showOpticalPulseSheet: Bool = false
    @State private var showTwinSheet: Bool = false

    @State private var currentResult: FaceScanRecord? = nil
    @State private var scanHistory: [FaceScanRecord] = FaceScanStore.load()
    @State private var alignedStreakFrames: Int = 0

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    // 0. MODE SWITCHER (Front Symmetry vs 90° Side Profile)
                    angleModePicker

                    // 1. APPLE VISION VIEWFINDER OR CAPTURED SPECIMEN
                    viewfinderCard

                    // 2. CAMERA, PHOTO LIBRARY & TRUEDEPTH BAR
                    controlBar

                    // 3. BIOMETRIC CRANIOFACIAL READOUTS
                    if let record = currentResult {
                        metricsGrid(record)
                    } else {
                        emptyPromptCard
                    }

                    // 4. CAPTURE ARCHIVE + DIFF COMPARE
                    if !scanHistory.isEmpty {
                        historySection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 32)
            }
            .background(ApexTheme.background)
            .navigationTitle("Face Scan")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if scanHistory.count >= 2 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Haptics.tap()
                            showCompareSheet = true
                        } label: {
                            Label("Compare", systemImage: "square.split.2x1")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ApexTheme.standCyan)
                        }
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let item = newItem else { return }
                Task { await analyzePickedPhoto(item) }
            }
            .onChange(of: controller.liveOverlay?.isAligned ?? false) { _, aligned in
                handleAlignmentTick(isAligned: aligned)
            }
            .onChange(of: angleMode) { _, mode in
                controller.targetMode = mode
                alignedStreakFrames = 0
            }
            .onDisappear {
                controller.stop()
            }
            .sheet(isPresented: $showCompareSheet) {
                FaceCompareSheet(history: scanHistory)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showTrueDepthSheet) {
                TrueDepth3DScanSheet { record in
                    currentResult = record
                    scanHistory.insert(record, at: 0)
                    FaceScanStore.save(scanHistory)
                    syncScanToMac(record)
                }
            }
            .sheet(isPresented: $showOpticalPulseSheet) {
                OpticalPulseSheet()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showTwinSheet) {
                TrueDepthTwinSheet()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Segmented Angle Selector + Auto-Capture Toggle
    private var angleModePicker: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(FaceScanAngleMode.allCases) { mode in
                    let selected = angleMode == mode
                    Button {
                        Haptics.tap()
                        angleMode = mode
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(selected ? .black : .secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selected ? ApexTheme.standCyan : Color.clear)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(ApexTheme.cardSurface)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(ApexTheme.subtleBorder, lineWidth: 0.5))

            Spacer()

            Button {
                Haptics.tap()
                autoCaptureOnAlign.toggle()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: autoCaptureOnAlign ? "scope" : "hand.tap")
                        .font(.system(size: 12, weight: .semibold))
                    Text(autoCaptureOnAlign ? "Auto-Snap" : "Manual")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(autoCaptureOnAlign ? ApexTheme.accentVolt : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(ApexTheme.cardSurface)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(ApexTheme.subtleBorder, lineWidth: 0.5))
            }
        }
    }

    // MARK: - Viewfinder Card
    private var viewfinderCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(ApexTheme.cardSurface)

            if let image = capturedImage {
                GeometryReader { geo in
                    let fittedRect = aspectFitRect(imageSize: image.size, containerSize: geo.size)

                    ZStack {
                        Color.black
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)

                        if showMeshOverlay, let overlay = controller.staticOverlay {
                            FaceMeshCanvas(overlay: overlay, drawRect: fittedRect)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            } else if controller.isCameraRunning {
                ZStack {
                    FaceCameraPreview(session: controller.session)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                    if showMeshOverlay, let liveOverlay = controller.liveOverlay {
                        GeometryReader { geo in
                            FaceMeshCanvas(
                                overlay: liveOverlay,
                                drawRect: CGRect(origin: .zero, size: geo.size)
                            )
                        }
                    }

                    // Live Precision Alignment Level Reticle
                    Circle()
                        .strokeBorder(
                            (controller.liveOverlay?.isAligned ?? false) ? ApexTheme.accentEmerald : Color.white.opacity(0.25),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
                        )
                        .frame(width: 220, height: 270)
                        .scaleEffect(x: 0.86, y: 1.0)
                }
            } else {
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(ApexTheme.standCyan.opacity(0.12))
                            .frame(width: 72, height: 72)
                        Image(systemName: angleMode == .front ? "faceid" : "person.crop.rectangle")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(ApexTheme.standCyan)
                    }

                    VStack(spacing: 4) {
                        Text(angleMode == .front ? "Craniofacial Vision" : "90° Lateral Profile")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(angleMode == .front
                             ? "Use Front Camera with pose leveling or pick a clear portrait from Photos."
                             : "Capture or pick a 90° side profile to calculate gonial jawline angle and forward growth.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.vertical, 36)
            }

            // Top Frosted Status Pill + Alignment Cue
            VStack {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusDotColor)
                            .frame(width: 7, height: 7)
                        Text(statusBadgeText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())

                    Spacer()

                    if capturedImage != nil || controller.isCameraRunning {
                        Button {
                            Haptics.tap()
                            showMeshOverlay.toggle()
                        } label: {
                            Image(systemName: showMeshOverlay ? "eye.fill" : "eye.slash.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                }
                Spacer()

                if controller.isCameraRunning, let live = controller.liveOverlay {
                    Text(live.alignmentCue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(live.isAligned ? ApexTheme.accentEmerald : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }
            .padding(14)
        }
        .frame(height: 360)
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(ApexTheme.subtleBorder, lineWidth: 0.5)
        )
    }

    // MARK: - Camera, Photo Library & TrueDepth Control Bar
    private var controlBar: some View {
        VStack(spacing: 10) {
            if let alert = noFaceAlert {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(ApexTheme.accentAmber)
                    Text(alert)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .appleCard(padding: 12, cornerRadius: 14)
            }

            HStack(spacing: 12) {
                if controller.cameraAvailable {
                    if controller.isCameraRunning {
                        Button {
                            captureLiveFrame()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "camera.aperture")
                                Text("Capture Now")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(ApexTheme.accentVolt)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    } else {
                        Button {
                            Haptics.tap()
                            noFaceAlert = nil
                            capturedImage = nil
                            currentResult = nil
                            alignedStreakFrames = 0
                            controller.targetMode = angleMode
                            controller.start()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: capturedImage != nil ? "arrow.counterclockwise" : "video.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(capturedImage != nil ? "Retake" : "Camera")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(ApexTheme.standCyan)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }

                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 14, weight: .semibold))
                        Text(isAnalyzing ? "Analyzing..." : "Choose Photo")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ApexTheme.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(ApexTheme.subtleBorder, lineWidth: 0.5)
                    )
                }
            }

            if ARFaceTrackingConfiguration.isSupported {
                Button {
                    Haptics.tap(.medium)
                    controller.stop()
                    showTrueDepthSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "cube.transparent.fill")
                            .foregroundStyle(ApexTheme.accentVolt)
                        Text("TrueDepth 3D Millimeter Depth Scan")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .appleCard(padding: 13, cornerRadius: 16)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Button {
                    Haptics.tap()
                    controller.stop()
                    showOpticalPulseSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ApexTheme.moveCrimson)
                        Text("10s PPG Pulse")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(ApexTheme.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(ApexTheme.subtleBorder, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    Haptics.tap()
                    controller.stop()
                    showTwinSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "faceid")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ApexTheme.standCyan)
                        Text("3D Digital Twin")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(ApexTheme.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(ApexTheme.subtleBorder, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Craniofacial Biometrics 2x2 Grid
    private func metricsGrid(_ record: FaceScanRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Text("Biometric Analysis")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    if let engine = record.depthEngine {
                        Text(engine)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(ApexTheme.standCyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(ApexTheme.standCyan.opacity(0.14))
                            .clipShape(Capsule())
                    }
                }
                Spacer()
                Text(record.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if let gonial = record.gonialAngleDeg, record.scanAngle == FaceScanAngleMode.sideProfile.rawValue {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    AppleBiometricTile(
                        title: "Gonial Angle",
                        value: String(format: "%.1f", gonial),
                        unit: "°",
                        detail: gonial <= 128 ? "Sharp Mandible" : "Obtuse Angle",
                        tint: ApexTheme.standCyan,
                        systemIcon: "angle"
                    )

                    AppleBiometricTile(
                        title: "Forward Growth",
                        value: String(format: "%.0f", record.forwardProjectionScore ?? 82),
                        unit: "/100",
                        detail: "Lateral Projection",
                        tint: ApexTheme.accentVolt,
                        systemIcon: "arrow.forward.circle"
                    )
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    AppleBiometricTile(
                        title: "Canthal Tilt",
                        value: record.canthalTilt,
                        unit: "",
                        detail: record.canthalAssessment,
                        tint: ApexTheme.standCyan,
                        systemIcon: "eye"
                    )

                    AppleBiometricTile(
                        title: "Symmetry",
                        value: String(format: "%.1f", record.symmetryPercent),
                        unit: "%",
                        detail: record.symmetryPercent >= 93 ? "Balanced Midline" : "Natural Asymmetry",
                        tint: ApexTheme.accentEmerald,
                        systemIcon: "scale.3d"
                    )

                    AppleBiometricTile(
                        title: "Midface Ratio",
                        value: String(format: "%.2f", record.midfaceRatio),
                        unit: "",
                        detail: "Ideal 0.95 – 1.05",
                        tint: ApexTheme.accentVolt,
                        systemIcon: "ruler"
                    )

                    AppleBiometricTile(
                        title: "Facial FWHR",
                        value: String(format: "%.2f", record.fwhrRatio),
                        unit: "",
                        detail: "Thirds \(record.facialThirds)",
                        tint: ApexTheme.moveCrimson,
                        systemIcon: "faceid"
                    )
                }
            }
        }
    }

    private var emptyPromptCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 20))
                .foregroundStyle(ApexTheme.standCyan)
            VStack(alignment: .leading, spacing: 2) {
                Text("Consistent Capture Calibration")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("With Auto-Snap enabled, APEX verifies head yaw & roll within ±6° before measuring to prevent perspective distortion.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appleCard(padding: 16, cornerRadius: 20)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Scan History")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                if scanHistory.count >= 2 {
                    Button("Compare Deltas") {
                        Haptics.tap()
                        showCompareSheet = true
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ApexTheme.standCyan)
                } else {
                    Text("\(scanHistory.count)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 10) {
                ForEach(scanHistory) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            if let gonial = item.gonialAngleDeg, item.scanAngle == FaceScanAngleMode.sideProfile.rawValue {
                                Text("Side Profile · Gonial \(String(format: "%.1f°", gonial))")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                            } else {
                                Text("Symmetry \(String(format: "%.1f%%", item.symmetryPercent)) · Tilt \(item.canthalTilt)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            Text("Midface \(String(format: "%.2f", item.midfaceRatio)) · FWHR \(String(format: "%.2f", item.fwhrRatio)) · \(item.date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            Haptics.tap()
                            scanHistory.removeAll { $0.id == item.id }
                            FaceScanStore.save(scanHistory)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .padding(8)
                        }
                    }
                    .appleCard(padding: 14, cornerRadius: 16)
                }
            }
        }
    }

    // MARK: - Actions & Calibration Handlers
    private var statusDotColor: Color {
        if isAnalyzing { return ApexTheme.accentVolt }
        if capturedImage != nil && currentResult != nil { return ApexTheme.accentEmerald }
        if controller.liveOverlay?.isAligned == true { return ApexTheme.accentEmerald }
        if controller.isCameraRunning { return ApexTheme.standCyan }
        return .gray
    }

    private var statusBadgeText: String {
        if isAnalyzing { return "Measuring Landmarks..." }
        if capturedImage != nil && currentResult != nil { return "Captured" }
        if let live = controller.liveOverlay {
            return live.isAligned ? "Aligned · Ready" : "Adjust Pose"
        }
        if controller.isCameraRunning { return "Position Face" }
        return "Standby"
    }

    private func handleAlignmentTick(isAligned: Bool) {
        guard controller.isCameraRunning, autoCaptureOnAlign, !isAnalyzing else { return }
        if isAligned {
            alignedStreakFrames += 1
            if alignedStreakFrames >= 2 {
                captureLiveFrame()
            }
        } else {
            alignedStreakFrames = 0
        }
    }

    private func captureLiveFrame() {
        guard !isAnalyzing else { return }
        Haptics.shutter()
        noFaceAlert = nil
        isAnalyzing = true

        controller.captureCurrentFrame { image in
            Task { @MainActor in
                controller.stop()
                if let captured = image {
                    let upright = normalizedUprightImage(captured)
                    capturedImage = upright
                    let (overlay, record) = await controller.analyzeStaticImage(upright, mode: angleMode)
                    controller.staticOverlay = overlay
                    isAnalyzing = false
                    if let rec = record {
                        currentResult = rec
                        scanHistory.insert(rec, at: 0)
                        FaceScanStore.save(scanHistory)
                        syncScanToMac(rec)
                        Haptics.success()
                    } else {
                        noFaceAlert = "No face detected. Retake in good lighting."
                        Haptics.warning()
                    }
                } else {
                    isAnalyzing = false
                    noFaceAlert = "Unable to capture frame."
                }
            }
        }
    }

    private func analyzePickedPhoto(_ item: PhotosPickerItem) async {
        Haptics.tap()
        noFaceAlert = nil
        isAnalyzing = true

        if let data = try? await item.loadTransferable(type: Data.self),
           let rawImage = UIImage(data: data) {
            controller.stop()
            let upright = normalizedUprightImage(rawImage)
            capturedImage = upright
            let (overlay, record) = await controller.analyzeStaticImage(upright, mode: angleMode)
            controller.staticOverlay = overlay
            isAnalyzing = false

            if let rec = record {
                currentResult = rec
                scanHistory.insert(rec, at: 0)
                FaceScanStore.save(scanHistory)
                syncScanToMac(rec)
                Haptics.success()
            } else {
                noFaceAlert = "No clear face found in that photo. Choose another portrait."
                Haptics.warning()
            }
        } else {
            isAnalyzing = false
            noFaceAlert = "Unable to load selected photo."
        }
        selectedPhotoItem = nil
    }

    private func syncScanToMac(_ record: FaceScanRecord) {
        health.syncEventToMac(extraPayload: [
            "faceScan": [
                "id": record.id.uuidString,
                "date": ISO8601DateFormatter().string(from: record.date),
                "canthalTilt": record.canthalTilt,
                "canthalAssessment": record.canthalAssessment,
                "symmetryPercent": record.symmetryPercent,
                "midfaceRatio": record.midfaceRatio,
                "fwhrRatio": record.fwhrRatio,
                "facialThirds": record.facialThirds,
                "scanAngle": record.scanAngle ?? "Front",
                "gonialAngleDeg": record.gonialAngleDeg ?? 0,
                "depthEngine": record.depthEngine ?? "Vision 2D"
            ]
        ])
    }

    private func normalizedUprightImage(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private func aspectFitRect(imageSize: CGSize, containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }
        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        return CGRect(x: (containerSize.width - w) / 2.0, y: (containerSize.height - h) / 2.0, width: w, height: h)
    }
}

// MARK: - Longitudinal Scan Comparison Sheet
private struct FaceCompareSheet: View {
    let history: [FaceScanRecord]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if history.count >= 2 {
                        let latest = history[0]
                        let baseline = history[history.count - 1]

                        Text("Comparing Latest vs Earliest Scan")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)

                        VStack(spacing: 12) {
                            deltaRow(
                                label: "Symmetry Index",
                                base: String(format: "%.1f%%", baseline.symmetryPercent),
                                current: String(format: "%.1f%%", latest.symmetryPercent),
                                delta: latest.symmetryPercent - baseline.symmetryPercent,
                                unit: "%"
                            )
                            let parseTilt: (String) -> Double? = { s in
                                Double(s.replacingOccurrences(of: "°", with: "").replacingOccurrences(of: "+", with: "").trimmingCharacters(in: .whitespaces))
                            }
                            if let t0 = parseTilt(baseline.canthalTilt), let t1 = parseTilt(latest.canthalTilt) {
                                deltaRow(
                                    label: "Canthal Tilt",
                                    base: baseline.canthalTilt,
                                    current: latest.canthalTilt,
                                    delta: t1 - t0,
                                    unit: "°"
                                )
                            }
                            deltaRow(
                                label: "Midface Ratio",
                                base: String(format: "%.2f", baseline.midfaceRatio),
                                current: String(format: "%.2f", latest.midfaceRatio),
                                delta: latest.midfaceRatio - baseline.midfaceRatio,
                                unit: ""
                            )
                            deltaRow(
                                label: "Facial FWHR",
                                base: String(format: "%.2f", baseline.fwhrRatio),
                                current: String(format: "%.2f", latest.fwhrRatio),
                                delta: latest.fwhrRatio - baseline.fwhrRatio,
                                unit: ""
                            )
                            if let g0 = baseline.gonialAngleDeg, let g1 = latest.gonialAngleDeg {
                                deltaRow(
                                    label: "Gonial Jaw Angle",
                                    base: String(format: "%.1f°", g0),
                                    current: String(format: "%.1f°", g1),
                                    delta: g1 - g0,
                                    unit: "°"
                                )
                            }
                            if let p0 = baseline.forwardProjectionScore, let p1 = latest.forwardProjectionScore {
                                deltaRow(
                                    label: "Forward Projection",
                                    base: String(format: "%.0f", p0),
                                    current: String(format: "%.0f", p1),
                                    delta: p1 - p0,
                                    unit: ""
                                )
                            }
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Baseline")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text(baseline.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Latest")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text(latest.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(ApexTheme.standCyan)
                            }
                        }
                        .appleCard(padding: 14, cornerRadius: 16)
                    }
                }
                .padding(20)
            }
            .background(ApexTheme.background)
            .navigationTitle("Longitudinal Delta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func deltaRow(label: String, base: String, current: String, delta: Double, unit: String) -> some View {
        let sign = delta >= 0 ? "+" : ""
        let color = abs(delta) < 0.05 ? Color.secondary : (delta >= 0 ? ApexTheme.accentEmerald : ApexTheme.accentAmber)
        return HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(base) → \(current)")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(String(format: "%@%.2f%@", sign, delta, unit))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .appleCard(padding: 14, cornerRadius: 16)
    }
}

// MARK: - ARKit TrueDepth 3D Millimeter Scanner Sheet (Physical Face ID iPhones)
private struct TrueDepth3DScanSheet: View {
    var onCaptured: (FaceScanRecord) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var arCoordinator = TrueDepthCoordinator()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if ARFaceTrackingConfiguration.isSupported {
                    TrueDepthARViewRepresentable(coordinator: arCoordinator)
                        .ignoresSafeArea(edges: .bottom)
                }

                VStack {
                    if !ARFaceTrackingConfiguration.isSupported {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "faceid")
                                .font(.system(size: 42))
                                .foregroundStyle(ApexTheme.standCyan)
                            Text("TrueDepth Hardware Required")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                            Text("TrueDepth infrared 3D millimeter geometry requires a physical iPhone with Face ID. Use 2D Optical Scan or Photo Import on this device.")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .appleCard(padding: 20, cornerRadius: 22)
                        .padding(20)
                    }
                    Spacer()
                    if ARFaceTrackingConfiguration.isSupported {
                        VStack(spacing: 12) {
                            HStack {
                                Text(arCoordinator.faceDetected ? "TrueDepth Mesh Locked" : "Position Face in TrueDepth Cone")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(arCoordinator.faceDetected ? ApexTheme.accentEmerald : .white)
                                Spacer()
                                if let mm = arCoordinator.interPupillaryMm {
                                    Text("IPD \(String(format: "%.1f mm", mm))")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(ApexTheme.standCyan)
                                }
                            }

                            Button {
                                if let rec = arCoordinator.snapshotRecord() {
                                    Haptics.success()
                                    onCaptured(rec)
                                    dismiss()
                                }
                            } label: {
                                Text("Capture 3D Millimeter Scan")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(arCoordinator.faceDetected ? ApexTheme.accentVolt : ApexTheme.elevatedSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .disabled(!arCoordinator.faceDetected)
                        }
                        .appleCard(padding: 16, cornerRadius: 22)
                        .padding(16)
                    }
                }
            }
            .navigationTitle("TrueDepth 3D")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private final class TrueDepthCoordinator: NSObject, ObservableObject, ARSessionDelegate {
    @Published var faceDetected: Bool = false
    @Published var interPupillaryMm: Double? = nil
    @Published var bizygomaticMm: Double? = nil
    private var lastSymmetry: Double = 95.0
    private var lastTiltDegrees: Double? = nil
    private var lastMidfaceRatio: Double? = nil
    private var lastFwhrRatio: Double? = nil
    private var lastFacialThirds: String? = nil
    private var lastForwardProjection: Double? = nil
    private var lastVisionTimestamp: CFAbsoluteTime = 0

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastVisionTimestamp > 0.35 else { return }
        lastVisionTimestamp = now

        let pb = frame.capturedImage
        let req = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pb, orientation: .leftMirrored, options: [:])
        try? handler.perform([req])

        guard let obs = req.results?.first, let lm = obs.landmarks else { return }
        let bbox = obs.boundingBox
        func flipPt(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: 1.0 - p.y) }
        let leftEye = (lm.leftEye?.normalizedPoints ?? []).map(flipPt)
        let rightEye = (lm.rightEye?.normalizedPoints ?? []).map(flipPt)
        let outerLips = (lm.outerLips?.normalizedPoints ?? []).map(flipPt)
        let lPupil = lm.leftPupil?.normalizedPoints.first.map(flipPt)
        let rPupil = lm.rightPupil?.normalizedPoints.first.map(flipPt)
        let leftBrow = (lm.leftEyebrow?.normalizedPoints ?? []).map(flipPt)
        let noseCrest = (lm.noseCrest?.normalizedPoints ?? []).map(flipPt)
        let contour = (lm.faceContour?.normalizedPoints ?? []).map(flipPt)

        var tiltSum = 0.0, tiltCount = 0.0
        if leftEye.count >= 4 {
            let outer = leftEye.min(by: { $0.x < $1.x }) ?? leftEye[0]
            let inner = leftEye.max(by: { $0.x < $1.x }) ?? leftEye[0]
            tiltSum += atan2(inner.y - outer.y, inner.x - outer.x) * 180.0 / .pi
            tiltCount += 1.0
        }
        if rightEye.count >= 4 {
            let inner = rightEye.min(by: { $0.x < $1.x }) ?? rightEye[0]
            let outer = rightEye.max(by: { $0.x < $1.x }) ?? rightEye[0]
            tiltSum += atan2(inner.y - outer.y, outer.x - inner.x) * 180.0 / .pi
            tiltCount += 1.0
        }
        let tilt = tiltCount > 0 ? max(-10.0, min(12.0, tiltSum / tiltCount)) : nil

        var midface: Double? = nil
        if let lp = lPupil, let rp = rPupil, let upperLip = outerLips.min(by: { $0.y < $1.y }) {
            let ipd = hypot(rp.x - lp.x, rp.y - lp.y)
            let verticalMid = abs(upperLip.y - ((lp.y + rp.y) / 2.0))
            if ipd > 0.01 {
                midface = max(0.75, min(1.25, ((Double(verticalMid / ipd)) * 100).rounded() / 100))
            }
        }
        let fwhr = bbox.height > 0
            ? max(1.55, min(2.15, ((Double(bbox.width / (bbox.height * 0.54))) * 100).rounded() / 100))
            : nil

        var thirdsLabel: String? = nil
        if let browY = (leftBrow.isEmpty ? nil : leftBrow.map(\.y).reduce(0, +) / CGFloat(leftBrow.count)),
           let noseBaseY = noseCrest.max(by: { $0.y < $1.y })?.y,
           let chinY = contour.max(by: { $0.y < $1.y })?.y {
            let midThird = abs(noseBaseY - browY)
            let lowerThird = abs(chinY - noseBaseY)
            if midThird > 0.02 && lowerThird > 0.02 {
                let ratio = midThird / lowerThird
                thirdsLabel = ratio < 0.88 ? "Strong Lower Third" : (ratio > 1.14 ? "Longer Midface" : "Balanced")
            }
        }

        DispatchQueue.main.async {
            if let t = tilt { self.lastTiltDegrees = t }
            if let m = midface { self.lastMidfaceRatio = m }
            if let f = fwhr { self.lastFwhrRatio = f }
            if let th = thirdsLabel { self.lastFacialThirds = th }
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let face = anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
            DispatchQueue.main.async { self.faceDetected = false }
            return
        }
        let vertices = face.geometry.vertices
        guard vertices.count > 400 else { return }

        // Left & right eye transforms in meters -> millimeters
        let lPos = face.leftEyeTransform.columns.3
        let rPos = face.rightEyeTransform.columns.3
        let ipdMeters = hypot(Double(lPos.x - rPos.x), Double(lPos.y - rPos.y))
        let ipdMm = ipdMeters * 1000.0

        // Sample bizygomatic width + left-vs-right horizontal-slice 3D mirror symmetry + maxillary projection
        var minX: Float = .greatestFiniteMagnitude
        var maxX: Float = -.greatestFiniteMagnitude
        var leftSliceX = [Double](repeating: 0, count: 14)
        var leftSliceZ = [Double](repeating: 0, count: 14)
        var leftSliceN = [Int](repeating: 0, count: 14)
        var rightSliceX = [Double](repeating: 0, count: 14)
        var rightSliceZ = [Double](repeating: 0, count: 14)
        var rightSliceN = [Int](repeating: 0, count: 14)
        var maxillaZSum = 0.0, maxillaN = 0
        var lateralZSum = 0.0, lateralN = 0

        for v in vertices {
            if v.y >= -0.045 && v.y <= 0.045 {
                if v.x < minX { minX = v.x }
                if v.x > maxX { maxX = v.x }
            }
            if abs(v.x) >= 0.012 && abs(v.x) <= 0.042 && v.y >= -0.025 && v.y <= 0.015 {
                maxillaZSum += Double(v.z * 1000.0)
                maxillaN += 1
            } else if abs(v.x) >= 0.055 && v.y >= -0.04 && v.y <= 0.03 {
                lateralZSum += Double(v.z * 1000.0)
                lateralN += 1
            }
            let bin = Int(((v.y + 0.075) / 0.14) * 14.0)
            if (0..<14).contains(bin) {
                if v.x < -0.010 {
                    leftSliceX[bin] += Double(abs(v.x) * 1000.0)
                    leftSliceZ[bin] += Double(v.z * 1000.0)
                    leftSliceN[bin] += 1
                } else if v.x > 0.010 {
                    rightSliceX[bin] += Double(abs(v.x) * 1000.0)
                    rightSliceZ[bin] += Double(v.z * 1000.0)
                    rightSliceN[bin] += 1
                }
            }
        }

        var symErrMm = 0.0
        var symSlices = 0
        for b in 0..<14 where leftSliceN[b] >= 3 && rightSliceN[b] >= 3 {
            let lmx = leftSliceX[b] / Double(leftSliceN[b])
            let rmx = rightSliceX[b] / Double(rightSliceN[b])
            let lmz = leftSliceZ[b] / Double(leftSliceN[b])
            let rmz = rightSliceZ[b] / Double(rightSliceN[b])
            symErrMm += hypot(lmx - rmx, lmz - rmz)
            symSlices += 1
        }

        let avgErrMm = symSlices > 0 ? symErrMm / Double(symSlices) : 2.8
        let widthMm = (maxX > minX) ? Double(maxX - minX) * 1000.0 : 132.0
        let symScore = max(84.0, min(99.5, 99.4 - avgErrMm * 1.45))
        let maxZ = maxillaN > 0 ? maxillaZSum / Double(maxillaN) : 34.0
        let latZ = lateralN > 0 ? lateralZSum / Double(lateralN) : -4.0
        let projScore = min(98.0, max(65.0, (48.0 + (maxZ - latZ) * 0.95).rounded()))

        DispatchQueue.main.async {
            self.faceDetected = true
            self.interPupillaryMm = (ipdMm * 10).rounded() / 10
            self.bizygomaticMm = (widthMm * 10).rounded() / 10
            self.lastSymmetry = (symScore * 10).rounded() / 10
            self.lastForwardProjection = projScore
        }
    }

    func snapshotRecord() -> FaceScanRecord? {
        guard faceDetected else { return nil }
        let ipd = interPupillaryMm ?? 63.0
        let zyg = bizygomaticMm ?? 134.0
        let derivedFwhr = lastFwhrRatio ?? max(1.55, min(2.15, ((zyg / (ipd * 1.15)) * 100).rounded() / 100))
        let tilt = lastTiltDegrees ?? 2.4
        let tiltStr = tilt >= 0 ? String(format: "+%.1f°", tilt) : String(format: "%.1f°", tilt)
        let tiltAssess = tilt >= 2.0 ? "Positive Tilt" : (tilt >= -1.0 ? "Neutral Tilt" : "Negative Tilt")
        let midface = lastMidfaceRatio ?? max(0.85, min(1.15, (((ipd / (zyg * 0.48)) * 100).rounded() / 100)))

        return FaceScanRecord(
            id: UUID(),
            date: Date(),
            canthalTilt: tiltStr,
            canthalAssessment: tiltAssess,
            symmetryPercent: lastSymmetry,
            midfaceRatio: midface,
            fwhrRatio: derivedFwhr,
            facialThirds: lastFacialThirds ?? "Proportion Pending",
            scanAngle: FaceScanAngleMode.front.rawValue,
            gonialAngleDeg: nil,
            forwardProjectionScore: lastForwardProjection,
            captureQuality: 1.0,
            depthEngine: "TrueDepth 3D"
        )
    }
}

private struct TrueDepthARViewRepresentable: UIViewRepresentable {
    let coordinator: TrueDepthCoordinator

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.session.delegate = coordinator
        if ARFaceTrackingConfiguration.isSupported {
            let cfg = ARFaceTrackingConfiguration()
            cfg.maximumNumberOfTrackedFaces = 1
            view.session.run(cfg, options: [.resetTracking, .removeExistingAnchors])
        }
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: ()) {
        uiView.session.pause()
    }
}

// MARK: - SwiftUI Contour Mesh Overlay Canvas
private struct FaceMeshCanvas: View {
    let overlay: DetectedFaceOverlay
    let drawRect: CGRect

    var body: some View {
        Canvas { ctx, _ in
            func mapPoint(_ p: CGPoint) -> CGPoint {
                CGPoint(
                    x: drawRect.minX + p.x * drawRect.width,
                    y: drawRect.minY + p.y * drawRect.height
                )
            }

            func strokePolyline(_ pts: [CGPoint], closed: Bool, color: Color, lineWidth: CGFloat = 1.4) {
                guard pts.count >= 2 else { return }
                var path = Path()
                path.move(to: mapPoint(pts[0]))
                for pt in pts.dropFirst() {
                    path.addLine(to: mapPoint(pt))
                }
                if closed { path.closeSubpath() }
                ctx.stroke(path, with: .color(color), lineWidth: lineWidth)
            }

            strokePolyline(overlay.contour, closed: false, color: ApexTheme.standCyan.opacity(0.85), lineWidth: 1.6)
            strokePolyline(overlay.leftEye, closed: true, color: ApexTheme.accentVolt, lineWidth: 1.4)
            strokePolyline(overlay.rightEye, closed: true, color: ApexTheme.accentVolt, lineWidth: 1.4)
            strokePolyline(overlay.leftEyebrow, closed: false, color: ApexTheme.standCyan.opacity(0.75), lineWidth: 1.3)
            strokePolyline(overlay.rightEyebrow, closed: false, color: ApexTheme.standCyan.opacity(0.75), lineWidth: 1.3)
            strokePolyline(overlay.noseCrest, closed: false, color: .white.opacity(0.7), lineWidth: 1.2)
            strokePolyline(overlay.outerLips, closed: true, color: ApexTheme.moveCrimson.opacity(0.85), lineWidth: 1.4)

            for pupil in [overlay.leftPupil, overlay.rightPupil].compactMap({ $0 }) {
                let p = mapPoint(pupil)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)), with: .color(ApexTheme.accentVolt))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Live AVFoundation + Apple Vision Controller
private class FaceVisionController: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var isCameraRunning: Bool = false
    @Published var liveOverlay: DetectedFaceOverlay? = nil
    @Published var staticOverlay: DetectedFaceOverlay? = nil

    var targetMode: FaceScanAngleMode = .front
    let cameraAvailable: Bool
    let session = AVCaptureSession()

    private let videoQueue = DispatchQueue(label: "apex.face.vision.queue", qos: .userInteractive)
    private let ciContext = CIContext()
    private var isConfigured = false
    private var latestSampleImage: UIImage? = nil
    private var pendingCaptureCompletion: ((UIImage?) -> Void)? = nil

    override init() {
        self.cameraAvailable = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
        super.init()
    }

    func start() {
        guard cameraAvailable else { return }
        if session.isRunning {
            DispatchQueue.main.async { self.isCameraRunning = true }
            return
        }

        videoQueue.async { [weak self] in
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
                output.setSampleBufferDelegate(self, queue: self.videoQueue)
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
            DispatchQueue.main.async { self.isCameraRunning = true }
        }
    }

    func stop() {
        guard session.isRunning else {
            DispatchQueue.main.async { self.isCameraRunning = false }
            return
        }
        videoQueue.async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async {
                self?.isCameraRunning = false
                self?.liveOverlay = nil
            }
        }
    }

    func captureCurrentFrame(completion: @escaping (UIImage?) -> Void) {
        videoQueue.async { [weak self] in
            if let img = self?.latestSampleImage {
                completion(img)
            } else {
                self?.pendingCaptureCompletion = completion
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
            let uiImage = UIImage(cgImage: cgImage)
            self.latestSampleImage = uiImage
            if let pending = self.pendingCaptureCompletion {
                self.pendingCaptureCompletion = nil
                pending(uiImage)
            }
        }

        let currentMode = targetMode
        let request = VNDetectFaceLandmarksRequest { [weak self] req, _ in
            guard let obs = req.results?.first as? VNFaceObservation else {
                DispatchQueue.main.async { self?.liveOverlay = nil }
                return
            }
            let (overlay, _) = Self.extractMetrics(from: obs, mode: currentMode)
            DispatchQueue.main.async {
                self?.liveOverlay = overlay
            }
        }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([request])
    }

    func analyzeStaticImage(_ image: UIImage, mode: FaceScanAngleMode) async -> (DetectedFaceOverlay?, FaceScanRecord?) {
        guard let cgImage = image.cgImage else { return (nil, nil) }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNDetectFaceLandmarksRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
                do {
                    try handler.perform([request])
                    if let obs = request.results?.first as? VNFaceObservation {
                        let (overlay, record) = Self.extractMetrics(from: obs, mode: mode)
                        continuation.resume(returning: (overlay, record))
                    } else {
                        continuation.resume(returning: (nil, nil))
                    }
                } catch {
                    continuation.resume(returning: (nil, nil))
                }
            }
        }
    }

    private static func extractMetrics(from obs: VNFaceObservation, mode: FaceScanAngleMode) -> (DetectedFaceOverlay, FaceScanRecord) {
        let bbox = obs.boundingBox
        func mapRegion(_ region: VNFaceLandmarkRegion2D?) -> [CGPoint] {
            guard let pts = region?.normalizedPoints else { return [] }
            return pts.map { p in
                let x = bbox.origin.x + p.x * bbox.size.width
                let y = 1.0 - (bbox.origin.y + p.y * bbox.size.height)
                return CGPoint(x: x, y: y)
            }
        }

        let contour = mapRegion(obs.landmarks?.faceContour)
        let leftEye = mapRegion(obs.landmarks?.leftEye)
        let rightEye = mapRegion(obs.landmarks?.rightEye)
        let leftEyebrow = mapRegion(obs.landmarks?.leftEyebrow)
        let rightEyebrow = mapRegion(obs.landmarks?.rightEyebrow)
        let noseCrest = mapRegion(obs.landmarks?.noseCrest)
        let outerLips = mapRegion(obs.landmarks?.outerLips)
        let leftPupilPts = mapRegion(obs.landmarks?.leftPupil)
        let rightPupilPts = mapRegion(obs.landmarks?.rightPupil)

        let lPupil = leftPupilPts.first
        let rPupil = rightPupilPts.first

        // Real Head-Pose Orientation Check (radians -> degrees)
        let yawDeg = (obs.yaw?.doubleValue ?? 0.0) * 180.0 / .pi
        let rollDeg = (obs.roll?.doubleValue ?? 0.0) * 180.0 / .pi

        let cue: String
        let aligned: Bool
        if mode == .sideProfile {
            if abs(yawDeg) < 35 {
                cue = "Turn 90° to Side Profile"
                aligned = false
            } else {
                cue = "Side Profile Locked · Steady"
                aligned = true
            }
        } else {
            if abs(rollDeg) > 6 {
                cue = "Level Head Horizontally"
                aligned = false
            } else if abs(yawDeg) > 7 {
                cue = yawDeg > 0 ? "Turn Slightly Right" : "Turn Slightly Left"
                aligned = false
            } else if bbox.width < 0.25 {
                cue = "Move Slightly Closer"
                aligned = false
            } else {
                cue = "Aligned · Auto-Capture Locked"
                aligned = true
            }
        }

        // Canthal Tilt
        var tiltSum = 0.0
        var tiltCount = 0.0
        if leftEye.count >= 4 {
            let outer = leftEye.min(by: { $0.x < $1.x }) ?? leftEye[0]
            let inner = leftEye.max(by: { $0.x < $1.x }) ?? leftEye[0]
            tiltSum += atan2(inner.y - outer.y, inner.x - outer.x) * 180.0 / .pi
            tiltCount += 1.0
        }
        if rightEye.count >= 4 {
            let inner = rightEye.min(by: { $0.x < $1.x }) ?? rightEye[0]
            let outer = rightEye.max(by: { $0.x < $1.x }) ?? rightEye[0]
            tiltSum += atan2(inner.y - outer.y, outer.x - inner.x) * 180.0 / .pi
            tiltCount += 1.0
        }
        let avgTilt = tiltCount > 0 ? tiltSum / tiltCount : 3.2
        let clampedTilt = max(-10.0, min(12.0, avgTilt))
        let tiltStr = clampedTilt >= 0 ? String(format: "+%.1f°", clampedTilt) : String(format: "%.1f°", clampedTilt)
        let tiltAssessment = clampedTilt >= 2.0 ? "Positive Tilt" : clampedTilt >= -1.0 ? "Neutral Tilt" : "Negative Tilt"

        // Midface Ratio
        var midface = 0.99
        if let lp = lPupil, let rp = rPupil, let upperLip = outerLips.min(by: { $0.y < $1.y }) {
            let ipd = hypot(rp.x - lp.x, rp.y - lp.y)
            let pupilMidY = (lp.y + rp.y) / 2.0
            let verticalMid = abs(upperLip.y - pupilMidY)
            if ipd > 0.01 {
                midface = max(0.75, min(1.25, ((Double(verticalMid / ipd)) * 100).rounded() / 100))
            }
        }

        // Bilateral Symmetry Index
        let faceMidX = bbox.midX
        var symPenalty = 0.0
        if let lp = lPupil, let rp = rPupil {
            symPenalty += abs(abs(lp.x - faceMidX) - abs(rp.x - faceMidX)) * 120.0
            symPenalty += abs(lp.y - rp.y) * 90.0
        }
        if !leftEye.isEmpty && !rightEye.isEmpty {
            let leCenter = leftEye.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
            let reCenter = rightEye.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
            let lx = leCenter.x / CGFloat(leftEye.count)
            let rx = reCenter.x / CGFloat(rightEye.count)
            symPenalty += abs(abs(lx - faceMidX) - abs(rx - faceMidX)) * 100.0
        }
        let symmetry = max(84.0, min(99.2, ((97.8 - symPenalty) * 10).rounded() / 10))

        // Facial FWHR
        let fwhr = bbox.height > 0 ? max(1.55, min(2.15, ((Double(bbox.width / (bbox.height * 0.54))) * 100).rounded() / 100)) : 1.82

        // Side-Profile Gonial Jaw Angle (computed along contour curvature when side-on)
        var gonialAngle: Double? = nil
        var forwardProj: Double? = nil
        if mode == .sideProfile && contour.count >= 9 {
            let pEar = contour[0]
            let pGonion = contour[contour.count / 3]
            let pChin = contour[contour.count / 2]
            let v1 = CGVector(dx: pEar.x - pGonion.x, dy: pEar.y - pGonion.y)
            let v2 = CGVector(dx: pChin.x - pGonion.x, dy: pChin.y - pGonion.y)
            let mag1 = hypot(v1.dx, v1.dy)
            let mag2 = hypot(v2.dx, v2.dy)
            if mag1 > 0.01 && mag2 > 0.01 {
                let cosA = max(-1.0, min(1.0, Double((v1.dx * v2.dx + v1.dy * v2.dy) / (mag1 * mag2))))
                gonialAngle = min(142.0, max(112.0, (acos(cosA) * 180.0 / .pi * 10).rounded() / 10))
                forwardProj = min(98.0, max(65.0, (100.0 - max(0, (gonialAngle ?? 125.0) - 118.0) * 1.1)))
            }
        }

        let topLeftRect = CGRect(
            x: bbox.origin.x,
            y: 1.0 - bbox.origin.y - bbox.size.height,
            width: bbox.size.width,
            height: bbox.size.height
        )

        let overlay = DetectedFaceOverlay(
            contour: contour,
            leftEye: leftEye,
            rightEye: rightEye,
            leftEyebrow: leftEyebrow,
            rightEyebrow: rightEyebrow,
            noseCrest: noseCrest,
            outerLips: outerLips,
            leftPupil: lPupil,
            rightPupil: rPupil,
            boundingBoxTopLeft: topLeftRect,
            yawDegrees: yawDeg,
            rollDegrees: rollDeg,
            alignmentCue: cue,
            isAligned: aligned
        )

        // Facial Thirds Ratio (Brow -> Nose Base vs Nose Base -> Chin Menton)
        var facialThirdsLabel = "Proportion Pending"
        if !leftEyebrow.isEmpty && !noseCrest.isEmpty && !contour.isEmpty {
            let browY = leftEyebrow.map(\.y).reduce(0, +) / CGFloat(leftEyebrow.count)
            let noseBaseY = noseCrest.max(by: { $0.y < $1.y })?.y ?? browY
            let chinY = contour.max(by: { $0.y < $1.y })?.y ?? noseBaseY
            let midThird = abs(noseBaseY - browY)
            let lowerThird = abs(chinY - noseBaseY)
            if midThird > 0.02 && lowerThird > 0.02 {
                let ratio = midThird / lowerThird
                if ratio < 0.88 {
                    facialThirdsLabel = "Strong Lower Third"
                } else if ratio > 1.14 {
                    facialThirdsLabel = "Longer Midface"
                } else {
                    facialThirdsLabel = "Balanced"
                }
            }
        }

        let record = FaceScanRecord(
            id: UUID(),
            date: Date(),
            canthalTilt: tiltStr,
            canthalAssessment: tiltAssessment,
            symmetryPercent: symmetry,
            midfaceRatio: midface,
            fwhrRatio: fwhr,
            facialThirds: facialThirdsLabel,
            scanAngle: mode.rawValue,
            gonialAngleDeg: gonialAngle,
            forwardProjectionScore: forwardProj,
            captureQuality: obs.faceCaptureQuality.map { Double($0) },
            depthEngine: mode == .sideProfile ? "Lateral Vision" : "Vision 2D"
        )
        return (overlay, record)
    }
}

private struct FaceCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {}
}

private final class PreviewContainerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

public enum FaceScanStore {
    private static let key = "apex_ios_face_scans_v1"

    public static func load() -> [FaceScanRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([FaceScanRecord].self, from: data) else {
            return []
        }
        return decoded
    }

    public static func save(_ records: [FaceScanRecord]) {
        if let encoded = try? JSONEncoder().encode(Array(records.prefix(25))) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
}
