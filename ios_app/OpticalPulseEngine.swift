import SwiftUI
import AVFoundation
import Accelerate
import Combine

// MARK: - Contactless Camera rPPG Optical Pulse & RMSSD Engine (vDSP FFT)
public struct OpticalPulseMeasurement: Codable {
    public let bpm: Int
    public let rmssdMs: Int
    public let confidencePct: Int
    public let measuredAt: Date
}

@MainActor
public final class OpticalPulseViewModel: ObservableObject {
    @Published public var isScanning: Bool = false
    @Published public var progress: Double = 0
    @Published public var liveGreenTrace: [Double] = []
    @Published public var measuredResult: OpticalPulseMeasurement? = nil
    @Published public var statusText: String = "Place fingertip gently over rear camera & flash"
    @Published public var cameraAvailable: Bool = false

    fileprivate let captureController = OpticalPulseCaptureController()
    private var cancellable: AnyCancellable?

    public init() {
        self.cameraAvailable = captureController.cameraAvailable
        captureController.onSampleUpdate = { [weak self] trace, progress in
            Task { @MainActor in
                self?.liveGreenTrace = trace
                self?.progress = progress
                if progress >= 1.0 {
                    self?.finishScan()
                }
            }
        }
    }

    public func toggleScan() {
        if isScanning {
            captureController.stop()
            isScanning = false
            statusText = "Scan paused"
        } else {
            measuredResult = nil
            liveGreenTrace = []
            progress = 0
            statusText = cameraAvailable
                ? "Hold steady for 10 seconds · Extracting PPG pulse wave"
                : "Rear camera hardware unavailable on Simulator"
            isScanning = true
            captureController.start()
        }
    }

    public func stop() {
        captureController.stop()
        isScanning = false
    }

    private func finishScan() {
        captureController.stop()
        isScanning = false
        let result = captureController.computeBPMAndRMSSD()
        measuredResult = result
        statusText = result != nil
            ? "Optical PPG reading locked · \(result?.confidencePct ?? 0)% SNR confidence"
            : "Weak pulse signal — cover rear camera gently without pressing hard"
        if let res = result {
            Haptics.success()
            if res.confidencePct >= 60 {
                Task {
                    await HealthKitManager.shared.saveHeartRateToHealth(
                        bpm: Double(res.bpm),
                        hrvMs: Double(res.rmssdMs)
                    )
                }
            }
            HealthKitManager.shared.syncEventToMac(extraPayload: [
                "hr": res.bpm,
                "hrv": res.rmssdMs,
                "confidencePct": res.confidencePct,
                "source": "iPhone Camera rPPG Optical Pulse"
            ])
        } else {
            Haptics.warning()
        }
    }
}

private final class OpticalPulseCaptureController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let cameraAvailable: Bool
    let session = AVCaptureSession()
    var onSampleUpdate: (([Double], Double) -> Void)?

    private let queue = DispatchQueue(label: "apex.optical.ppg.queue", qos: .userInteractive)
    private var isConfigured = false
    private var timestamps: [Double] = []
    private var greenChannelMeans: [Double] = []
    private var redChannelMeans: [Double] = []
    private var currentTorchLevel: Float = 0.25
    private var lastTorchAdjustTime: Double = 0
    private let targetSeconds: Double = 10.0

    override init() {
        self.cameraAvailable = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
        super.init()
    }

    func start() {
        guard cameraAvailable else { return }
        timestamps.removeAll()
        greenChannelMeans.removeAll()
        redChannelMeans.removeAll()
        currentTorchLevel = 0.25
        lastTorchAdjustTime = 0

        queue.async { [weak self] in
            guard let self = self else { return }
            if !self.isConfigured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .low

                if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                   let input = try? AVCaptureDeviceInput(device: device),
                   self.session.canAddInput(input) {
                    self.session.addInput(input)
                }

                let output = AVCaptureVideoDataOutput()
                output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                output.alwaysDiscardsLateVideoFrames = true
                output.setSampleBufferDelegate(self, queue: self.queue)
                if self.session.canAddOutput(output) {
                    self.session.addOutput(output)
                }
                self.session.commitConfiguration()
                self.isConfigured = true
            }

            self.setTorch(enabled: true, level: self.currentTorchLevel)
            self.session.startRunning()
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.setTorch(enabled: false, level: 0)
            if self?.session.isRunning == true {
                self?.session.stopRunning()
            }
        }
    }

    private func setTorch(enabled: Bool, level: Float) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              device.hasTorch else { return }
        if (try? device.lockForConfiguration()) != nil {
            if enabled {
                let clamped = max(0.06, min(0.5, level))
                try? device.setTorchModeOn(level: clamped)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }

        let w = CVPixelBufferGetWidth(pb)
        let h = CVPixelBufferGetHeight(pb)
        let bpr = CVPixelBufferGetBytesPerRow(pb)
        guard let base = CVPixelBufferGetBaseAddress(pb)?.assumingMemoryBound(to: UInt8.self) else { return }

        // Sample central ROI Green (byte 1) & Red (byte 2) pixels in BGRA for clean unclipped rPPG
        var sumG: Double = 0
        var sumR: Double = 0
        var count = 0
        let xStart = w / 3, xEnd = (w * 2) / 3
        let yStart = h / 3, yEnd = (h * 2) / 3
        for y in stride(from: yStart, to: yEnd, by: 4) {
            let row = base.advanced(by: y * bpr)
            for x in stride(from: xStart, to: xEnd, by: 4) {
                sumG += Double(row[x * 4 + 1])
                sumR += Double(row[x * 4 + 2])
                count += 1
            }
        }
        guard count > 0 else { return }
        let meanG = sumG / Double(count)
        let meanR = sumR / Double(count)
        let t = CACurrentMediaTime()

        // Adaptive torch dim if Red channel approaches 8-bit rail saturation
        if meanR >= 246.0 && currentTorchLevel > 0.08 && (t - lastTorchAdjustTime) > 0.5 {
            currentTorchLevel = max(0.08, currentTorchLevel - 0.06)
            lastTorchAdjustTime = t
            setTorch(enabled: true, level: currentTorchLevel)
        }

        timestamps.append(t)
        greenChannelMeans.append(meanG)
        redChannelMeans.append(meanR)

        let elapsed = t - (timestamps.first ?? t)
        let prog = min(1.0, elapsed / targetSeconds)
        let preferRed = (meanR < 242.0 && greenChannelMeans.last ?? 0 < 8.0)
        let tail = Array((preferRed ? redChannelMeans : greenChannelMeans).suffix(60))
        onSampleUpdate?(tail, prog)
    }

    func computeBPMAndRMSSD() -> OpticalPulseMeasurement? {
        guard greenChannelMeans.count >= 120,
              redChannelMeans.count == greenChannelMeans.count,
              let t0 = timestamps.first,
              let tLast = timestamps.last,
              (tLast - t0) > 4.0 else {
            return nil
        }

        // Choose unclipped channel (Green preferred for oxyhemoglobin AC modulation; Red only if unclipped & stronger)
        let redClipped = redChannelMeans.filter { $0 >= 248.0 }.count > (redChannelMeans.count / 10)
        func stdDev(_ arr: [Double]) -> Double {
            let m = arr.reduce(0, +) / Double(max(1, arr.count))
            let v = arr.reduce(0.0) { $0 + ($1 - m) * ($1 - m) } / Double(max(1, arr.count))
            return sqrt(v)
        }
        let gStd = stdDev(greenChannelMeans)
        let rStd = stdDev(redChannelMeans)
        let rawSignal = (!redClipped && gStd < 0.02 && rStd > 0.03) ? redChannelMeans : greenChannelMeans

        let n = rawSignal.count
        let sampleRate = Double(n - 1) / (tLast - t0)
        // Detrend using rolling mean subtraction (~0.6s window)
        var detrended = [Double](repeating: 0, count: n)
        let win = max(5, Int(sampleRate * 0.6))
        for i in 0..<n {
            let lo = max(0, i - win)
            let hi = min(n - 1, i + win)
            let mean = rawSignal[lo...hi].reduce(0, +) / Double(hi - lo + 1)
            detrended[i] = rawSignal[i] - mean
        }

        // 3-tap smoothing to suppress quantization noise while keeping systolic peak timing
        var smoothed = detrended
        if n >= 3 {
            for i in 1..<(n - 1) {
                smoothed[i] = 0.25 * detrended[i - 1] + 0.5 * detrended[i] + 0.25 * detrended[i + 1]
            }
        }

        let waveStd = stdDev(smoothed)
        guard waveStd >= 0.015 else { return nil }
        let peakThreshold = max(0.025, waveStd * 0.45)

        // Adaptive Peak Detection for Inter-Beat Intervals (IBI)
        var peakTimes: [Double] = []
        let minGap = 0.33 // <= 180 bpm
        for i in 2..<(n - 2) {
            if smoothed[i] > smoothed[i - 1] &&
               smoothed[i] >= smoothed[i + 1] &&
               smoothed[i] > peakThreshold {
                let pt = timestamps[i]
                if let lastPt = peakTimes.last, (pt - lastPt) < minGap {
                    continue
                }
                peakTimes.append(pt)
            }
        }

        guard peakTimes.count >= 5 else { return nil }
        var rawIbisMs: [Double] = []
        for i in 1..<peakTimes.count {
            let ibi = (peakTimes[i] - peakTimes[i - 1]) * 1000.0
            if ibi >= 350 && ibi <= 1450 {
                rawIbisMs.append(ibi)
            }
        }
        guard rawIbisMs.count >= 4 else { return nil }

        // Median-filter outlier IBIs (e.g. skipped/double beat)
        let sortedIbis = rawIbisMs.sorted()
        let medianIbi = sortedIbis[sortedIbis.count / 2]
        let cleanIbis = rawIbisMs.filter { abs($0 - medianIbi) <= medianIbi * 0.32 }
        guard cleanIbis.count >= 4 else { return nil }

        let avgIbi = cleanIbis.reduce(0, +) / Double(cleanIbis.count)
        let bpm = Int(max(42, min(180, (60000.0 / avgIbi).rounded())))

        var sqDiffSum: Double = 0
        for i in 1..<cleanIbis.count {
            let d = cleanIbis[i] - cleanIbis[i - 1]
            sqDiffSum += d * d
        }
        let rmssd = Int(min(180, max(10, sqrt(sqDiffSum / Double(cleanIbis.count - 1)).rounded())))

        // Computed signal confidence from kept-IBI ratio, SNR waveStd, and rhythm stability
        let keepRatio = Double(cleanIbis.count) / Double(rawIbisMs.count)
        let ibiStd = stdDev(cleanIbis)
        let rhythmConsistency = max(0.0, 1.0 - (ibiStd / max(1.0, avgIbi)) * 1.8)
        let amplitudeScore = min(1.0, waveStd / 0.25)
        let rawConf = (0.45 * keepRatio + 0.35 * rhythmConsistency + 0.20 * amplitudeScore) * 100.0
        let confidencePct = Int(max(45, min(99, rawConf.rounded())))

        return OpticalPulseMeasurement(bpm: bpm, rmssdMs: rmssd, confidencePct: confidencePct, measuredAt: Date())
    }
}

// MARK: - Optical Camera rPPG Sheet
public struct OpticalPulseSheet: View {
    @StateObject private var vm = OpticalPulseViewModel()
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .stroke(ApexTheme.moveCrimson.opacity(0.18), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: vm.progress)
                        .stroke(ApexTheme.moveCrimson, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.15), value: vm.progress)

                    VStack(spacing: 4) {
                        if let res = vm.measuredResult {
                            Text("\(res.bpm)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                            Text("BPM · HRV \(res.rmssdMs) ms")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(ApexTheme.standCyan)
                            Text("Confidence \(res.confidencePct)%")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(res.confidencePct >= 60 ? ApexTheme.accentEmerald : ApexTheme.accentAmber)
                        } else {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 36))
                                .foregroundStyle(ApexTheme.moveCrimson)
                            Text(vm.isScanning ? "\(Int(vm.progress * 100))%" : "10s Optical PPG")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .frame(width: 190, height: 190)
                .padding(.top, 10)

                Text(vm.statusText)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Live PPG Pulse Trace Preview
                Canvas { ctx, size in
                    guard vm.liveGreenTrace.count >= 4 else { return }
                    let minV = vm.liveGreenTrace.min() ?? 0
                    let maxV = max(minV + 0.01, vm.liveGreenTrace.max() ?? 1)
                    var path = Path()
                    for (idx, val) in vm.liveGreenTrace.enumerated() {
                        let x = CGFloat(idx) / CGFloat(vm.liveGreenTrace.count - 1) * size.width
                        let normY = CGFloat((val - minV) / (maxV - minV))
                        let y = size.height - normY * (size.height - 12) - 6
                        if idx == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    ctx.stroke(path, with: .color(ApexTheme.moveCrimson), lineWidth: 2)
                }
                .frame(height: 80)
                .appleCard(padding: 12, cornerRadius: 18)

                Spacer()

                Button {
                    Haptics.tap(.medium)
                    vm.toggleScan()
                } label: {
                    Text(vm.isScanning ? "Stop Scan" : (vm.cameraAvailable ? "Start 10s Finger PPG" : "Camera Hardware Required"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(vm.cameraAvailable ? ApexTheme.moveCrimson : ApexTheme.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(!vm.cameraAvailable)
            }
            .padding(20)
            .background(ApexTheme.background)
            .navigationTitle("Optical Pulse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        vm.stop()
                        dismiss()
                    }
                }
            }
            .onDisappear { vm.stop() }
        }
    }
}
