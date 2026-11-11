import SwiftUI
import Combine
import AVFoundation
import Accelerate
import Charts

// MARK: - Morning Vocal Resonance Reading
public struct VoiceBiomarkerReading: Codable, Identifiable, Equatable {
    public let id: UUID
    public let date: Date
    public let fundamentalPitchHz: Double
    public let jitterPercent: Double
    public let signalRMS: Double
    public var chestResonancePct: Double? = nil
    public var cnsStressScore: Int? = nil
}

@MainActor
public final class VoiceBiomarkerStore: ObservableObject {
    public static let shared = VoiceBiomarkerStore()

    @Published public private(set) var history: [VoiceBiomarkerReading] = []

    private let key = "apex_voice_biomarker_history_v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([VoiceBiomarkerReading].self, from: data) {
            self.history = decoded
        }
    }

    public var latest: VoiceBiomarkerReading? { history.first }

    public var baselinePitchHz: Double? {
        guard history.count >= 2 else { return latest?.fundamentalPitchHz }
        let sum = history.dropFirst().reduce(0.0) { $0 + $1.fundamentalPitchHz }
        return sum / Double(history.count - 1)
    }

    public func save(_ reading: VoiceBiomarkerReading) {
        history.insert(reading, at: 0)
        if history.count > 45 { history = Array(history.prefix(45)) }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: key)
        }
        HealthKitManager.shared.syncEventToMac(extraPayload: [
            "vocalPitchHz": reading.fundamentalPitchHz,
            "vocalJitterPct": reading.jitterPercent
        ])
    }

    public func reloadFromDisk() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([VoiceBiomarkerReading].self, from: data) {
            history = decoded
        } else {
            history = []
        }
    }
}

// MARK: - Acoustic F0 & Jitter Engine (AVAudioEngine + Accelerate vDSP)
@MainActor
public final class VoiceBiomarkerEngine: ObservableObject {
    public enum Status: Equatable {
        case idle
        case recording(progress: Double)
        case completed(VoiceBiomarkerReading)
        case failed(String)
    }

    @Published public private(set) var status: Status = .idle
    @Published public private(set) var livePitchHz: Double = 0
    @Published public private(set) var liveChestResonancePct: Double = 0
    @Published public private(set) var liveLevel: Float = 0

    private let audioEngine = AVAudioEngine()
    private var framePitchHistory: [Double] = []
    private var frameRMSHistory: [Double] = []
    private var frameChestResonanceHistory: [Double] = []
    private var sampleRate: Double = 44100
    private var timerTask: Task<Void, Never>?

    public init() {}

    public func startFiveSecondCapture() {
        framePitchHistory.removeAll()
        frameRMSHistory.removeAll()
        frameChestResonanceHistory.removeAll()
        livePitchHz = 0
        liveChestResonancePct = 0
        Haptics.tap()

        Task { [weak self] in
            let granted = await AVAudioApplication.requestRecordPermission()
            guard let self else { return }
            guard granted else {
                self.status = .failed("Enable Microphone access in Settings to measure morning F0 resonance.")
                return
            }

            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
                try session.setActive(true)

                let input = self.audioEngine.inputNode
                let format = input.outputFormat(forBus: 0)
                guard format.channelCount > 0, format.sampleRate > 8000 else {
                    self.status = .failed("Audio input unavailable on this device.")
                    return
                }
                self.sampleRate = format.sampleRate

                input.removeTap(onBus: 0)
                input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
                    guard let channelData = buffer.floatChannelData?[0] else { return }
                    let count = Int(buffer.frameLength)
                    let samples = Array(UnsafeBufferPointer(start: channelData, count: count))
                    let sr = buffer.format.sampleRate
                    Task { @MainActor [weak self] in
                        self?.analyzeBuffer(samples, sampleRate: sr)
                    }
                }

                self.audioEngine.prepare()
                try self.audioEngine.start()
                self.status = .recording(progress: 0)

                self.timerTask?.cancel()
                self.timerTask = Task { [weak self] in
                    for step in 1...50 {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            self?.status = .recording(progress: Double(step) / 50.0)
                        }
                    }
                    await MainActor.run {
                        self?.finishCapture()
                    }
                }
            } catch {
                self.status = .failed("Microphone stream unavailable: \(error.localizedDescription)")
            }
        }
    }

    public func stopCapture() {
        timerTask?.cancel()
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if case .recording = status {
            status = .idle
        }
    }

    private func analyzeBuffer(_ samples: [Float], sampleRate: Double) {
        guard samples.count >= 1024 else { return }

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        liveLevel = min(1.0, rms * 10.0)
        guard rms > 0.008 else { return } // Ignore background silence

        let minLag = max(20, Int(sampleRate / 320.0)) // 320 Hz max F0
        let maxLag = min(samples.count / 2, Int(sampleRate / 65.0)) // 65 Hz min F0
        guard maxLag > minLag else { return }

        var energyZero: Float = 0
        let windowLen = samples.count / 2
        vDSP_dotpr(samples, 1, samples, 1, &energyZero, vDSP_Length(windowLen))
        guard energyZero > 1e-6 else { return }

        var bestLag = 0
        var bestNormCorr: Float = 0

        samples.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            for lag in minLag...maxLag {
                var corr: Float = 0
                vDSP_dotpr(base, 1, base + lag, 1, &corr, vDSP_Length(windowLen))
                let normalized = corr / energyZero
                if normalized > bestNormCorr {
                    bestNormCorr = normalized
                    bestLag = lag
                }
            }
        }

        if bestNormCorr > 0.55, bestLag > 0 {
            let f0 = sampleRate / Double(bestLag)
            livePitchHz = (f0 * 10).rounded() / 10
            framePitchHistory.append(f0)
            frameRMSHistory.append(Double(rms))

            // 2048-pt Hann-windowed vDSP DFT: Chest Resonance (85–250 Hz) vs Vocal Tension (1.5–3.5 kHz)
            let fftN = min(2048, samples.count >= 2048 ? 2048 : 1024)
            if fftN >= 1024, let setup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftN), .FORWARD) {
                var hann = [Float](repeating: 0, count: fftN)
                vDSP_hann_window(&hann, vDSP_Length(fftN), Int32(vDSP_HANN_NORM))
                var realIn = [Float](repeating: 0, count: fftN)
                for i in 0..<fftN { realIn[i] = samples[i] * hann[i] }
                let imagZero = [Float](repeating: 0, count: fftN)
                var outR = [Float](repeating: 0, count: fftN)
                var outI = [Float](repeating: 0, count: fftN)
                vDSP_DFT_Execute(setup, realIn, imagZero, &outR, &outI)
                vDSP_DFT_DestroySetup(setup)

                var chestE = 0.0
                var highE = 0.0
                for k in 1..<(fftN / 2) {
                    let freq = Double(k) * sampleRate / Double(fftN)
                    let pwr = Double(outR[k] * outR[k] + outI[k] * outI[k])
                    if freq >= 85.0 && freq <= 250.0 {
                        chestE += pwr
                    } else if freq >= 1500.0 && freq <= 3500.0 {
                        highE += pwr
                    }
                }
                let denom = max(1e-9, chestE + highE)
                let chestPct = min(98.0, max(5.0, (chestE / denom) * 100.0))
                liveChestResonancePct = chestPct.rounded()
                frameChestResonanceHistory.append(chestPct)
            }
        }
    }

    private func finishCapture() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        guard framePitchHistory.count >= 5 else {
            status = .failed("Hold a steady \"Aaaah\" closer to the mic so Pitch F0 can lock on.")
            return
        }

        let sorted = framePitchHistory.sorted()
        let medianPitch = sorted[sorted.count / 2]

        // Jitter: cycle-to-cycle period perturbation relative to mean period
        let periods = framePitchHistory.map { 1.0 / max($0, 50.0) }
        var diffSum = 0.0
        for i in 1..<periods.count {
            diffSum += abs(periods[i] - periods[i - 1])
        }
        let meanPeriod = periods.reduce(0, +) / Double(periods.count)
        let jitterPct = min(12.0, ((diffSum / Double(max(1, periods.count - 1))) / max(meanPeriod, 1e-5)) * 100.0)
        let avgRMS = frameRMSHistory.reduce(0, +) / Double(frameRMSHistory.count)

        let sortedChest = frameChestResonanceHistory.sorted()
        let medianChestPct = sortedChest.isEmpty ? nil : ((sortedChest[sortedChest.count / 2] * 10).rounded() / 10)
        let pitchShiftPenalty = VoiceBiomarkerStore.shared.baselinePitchHz.map { max(0.0, medianPitch - $0) * 1.4 } ?? 0.0
        let jitterPenalty = jitterPct * 12.0
        let chestCredit = (medianChestPct ?? 55.0) * 0.35
        let cnsStress = Int(max(5.0, min(95.0, (28.0 + jitterPenalty + pitchShiftPenalty - (chestCredit - 18.0)).rounded())))

        let reading = VoiceBiomarkerReading(
            id: UUID(),
            date: Date(),
            fundamentalPitchHz: (medianPitch * 10).rounded() / 10,
            jitterPercent: (jitterPct * 100).rounded() / 100,
            signalRMS: avgRMS,
            chestResonancePct: medianChestPct,
            cnsStressScore: cnsStress
        )
        VoiceBiomarkerStore.shared.save(reading)
        status = .completed(reading)
        Haptics.success()
    }
}

// MARK: - Morning Voice Biomarker Sheet
public struct VoiceBiomarkerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = VoiceBiomarkerEngine()
    @ObservedObject private var store = VoiceBiomarkerStore.shared

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    liveCheckCard
                    latestSummaryCard
                    if store.history.count >= 2 {
                        trendChartCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(ApexTheme.bg.ignoresSafeArea())
            .navigationTitle("Vocal Resonance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        engine.stopCapture()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear { engine.stopCapture() }
    }

    private var liveCheckCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(ApexTheme.cardElevated, lineWidth: 10)
                    .frame(width: 140, height: 140)

                if case .recording(let progress) = engine.status {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(ApexTheme.purple, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 140, height: 140)
                }

                VStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.title2)
                        .foregroundStyle(ApexTheme.purple)
                    if engine.livePitchHz > 0 {
                        Text("\(Int(engine.livePitchHz.rounded())) Hz")
                            .font(.title2.weight(.bold).monospacedDigit())
                    } else if let latest = store.latest {
                        Text("\(Int(latest.fundamentalPitchHz.rounded())) Hz")
                            .font(.title2.weight(.bold).monospacedDigit())
                    } else {
                        Text("F0 Check")
                            .font(.headline.weight(.semibold))
                    }
                }
            }
            .padding(.top, 8)

            switch engine.status {
            case .idle:
                Text("Hold a natural, steady \"Aaaah\" tone for 5 seconds. Measures Fundamental Pitch (F0), vocal fold jitter & chest resonance FFT for CNS readiness.")
                    .font(.subheadline)
                    .foregroundStyle(ApexTheme.secondaryText)
                    .multilineTextAlignment(.center)

                Button {
                    engine.startFiveSecondCapture()
                } label: {
                    Label("Start 5s Voice Check", systemImage: "mic.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(ApexTheme.purple)

            case .recording(let progress):
                Text("Sustained phonation · \(Int((1 - progress) * 5) + 1)s")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ApexTheme.purple)

                ProgressView(value: Double(engine.liveLevel))
                    .tint(ApexTheme.purple)

                Button("Cancel") {
                    engine.stopCapture()
                }
                .buttonStyle(.bordered)

            case .completed(let reading):
                VStack(spacing: 6) {
                    Text("F0: \(String(format: "%.1f", reading.fundamentalPitchHz)) Hz · Jitter \(String(format: "%.2f", reading.jitterPercent))%")
                        .font(.headline)
                        .foregroundStyle(ApexTheme.green)
                    if let chest = reading.chestResonancePct, let cns = reading.cnsStressScore {
                        Text("Chest Resonance: \(Int(chest.rounded()))% · CNS Strain: \(cns)/100")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ApexTheme.standCyan)
                    }
                    Button("Measure Again") {
                        engine.startFiveSecondCapture()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ApexTheme.purple)
                }

            case .failed(let msg):
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(ApexTheme.orange)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    engine.startFiveSecondCapture()
                }
                .buttonStyle(.borderedProminent)
                .tint(ApexTheme.purple)
            }
        }
        .padding(20)
        .appleCard(cornerRadius: 22)
    }

    @ViewBuilder
    private var latestSummaryCard: some View {
        if let latest = store.latest {
            VStack(alignment: .leading, spacing: 10) {
                Text("Latest Acoustic Biomarkers")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    VStack(alignment: .leading) {
                        Text("Latest Pitch F0")
                            .font(.caption)
                            .foregroundStyle(ApexTheme.secondaryText)
                        Text("\(String(format: "%.1f", latest.fundamentalPitchHz)) Hz")
                            .font(.title3.weight(.bold).monospacedDigit())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading) {
                        Text("Vocal Jitter")
                            .font(.caption)
                            .foregroundStyle(ApexTheme.secondaryText)
                        Text("\(String(format: "%.2f", latest.jitterPercent))%")
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(latest.jitterPercent < 2.2 ? ApexTheme.green : ApexTheme.orange)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let chest = latest.chestResonancePct {
                        VStack(alignment: .leading) {
                            Text("Chest Resonance")
                                .font(.caption)
                                .foregroundStyle(ApexTheme.secondaryText)
                            Text("\(Int(chest.rounded()))%")
                                .font(.title3.weight(.bold).monospacedDigit())
                                .foregroundStyle(ApexTheme.standCyan)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let cns = latest.cnsStressScore {
                        VStack(alignment: .leading) {
                            Text("CNS Vocal Load")
                                .font(.caption)
                                .foregroundStyle(ApexTheme.secondaryText)
                            Text("\(cns) / 100")
                                .font(.title3.weight(.bold).monospacedDigit())
                                .foregroundStyle(cns > 55 ? ApexTheme.orange : ApexTheme.green)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if let baseline = store.baselinePitchHz, store.history.count > 1 {
                    let delta = latest.fundamentalPitchHz - baseline
                    Text("Baseline F0: \(String(format: "%.1f", baseline)) Hz (\(String(format: "%+.1f", delta)) Hz today)")
                        .font(.caption)
                        .foregroundStyle(ApexTheme.secondaryText)
                }
            }
            .padding(18)
            .appleCard(cornerRadius: 20)
        }
    }

    private var trendChartCard: some View {
        let chronological = Array(store.history.prefix(14).reversed())
        return VStack(alignment: .leading, spacing: 10) {
            Text("Pitch F0 Longitudinal Trend")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            Chart(chronological) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Hz", item.fundamentalPitchHz)
                )
                .foregroundStyle(ApexTheme.purple)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                PointMark(
                    x: .value("Date", item.date),
                    y: .value("Hz", item.fundamentalPitchHz)
                )
                .foregroundStyle(ApexTheme.standCyan)
            }
            .frame(height: 130)
        }
        .padding(18)
        .appleCard(cornerRadius: 20)
    }
}
