import SwiftUI
import AVFoundation
import Combine
import Charts
import os

// MARK: - Persistent Stores for Thermal Contrast, Cognitive N-Back, NSDR & Decathlon Benchmarks
public struct ThermalSessionRecord: Identifiable, Codable {
    public let id: UUID
    public let date: Date
    public let modality: String
    public let durationMinutes: Double
    public let temperatureC: Double
}

public struct NBackSessionRecord: Identifiable, Codable {
    public let id: UUID
    public let date: Date
    public let nLevel: Int
    public let trials: Int
    public let accuracyPct: Int
}

public struct MewingSessionRecord: Identifiable, Codable {
    public let id: UUID
    public let date: Date
    public let durationMinutes: Double
}

public struct DecathlonBenchmarkState: Codable, Equatable {
    public var deadHangSec: Double = 0
    public var gripStrengthKg: Double = 0
    public var farmersCarryBwRatio: Double = 0
    public var wallSitSec: Double = 0
    public var singleLegEyesClosedSec: Double = 0
    public var floorGetUpScore: Int = 0
    public var maxPushups: Int = 0
    public var verticalJumpCm: Double = 0
    public var updatedAt: Date = Date()
}

@MainActor
public final class ThermalBrainStore: ObservableObject {
    public static let shared = ThermalBrainStore()

    @Published public var thermalSessions: [ThermalSessionRecord] = []
    @Published public var nBackSessions: [NBackSessionRecord] = []
    @Published public var mewingSessions: [MewingSessionRecord] = []
    @Published public var decathlon: DecathlonBenchmarkState = DecathlonBenchmarkState()

    private let thermalKey = "apex_thermal_sessions_v1"
    private let nbackKey = "apex_nback_history_v1"
    private let mewingKey = "apex_mewing_history_v1"
    private let decathlonKey = "apex_decathlon_benchmarks_v1"

    private init() {
        load()
    }

    public func reloadFromDisk() {
        load()
    }

    public var weeklySaunaMinutes: Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return thermalSessions.filter { $0.date >= cutoff && $0.modality.contains("Sauna") }.reduce(0) { $0 + $1.durationMinutes }
    }

    public var weeklyColdMinutes: Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return thermalSessions.filter { $0.date >= cutoff && $0.modality.contains("Cold") }.reduce(0) { $0 + $1.durationMinutes }
    }

    public func logThermalSession(modality: String, minutes: Double, temperatureC: Double) {
        let entry = ThermalSessionRecord(id: UUID(), date: Date(), modality: modality, durationMinutes: (minutes * 10).rounded() / 10, temperatureC: temperatureC)
        thermalSessions.insert(entry, at: 0)
        thermalSessions = Array(thermalSessions.prefix(40))
        if let d = try? JSONEncoder().encode(thermalSessions) {
            UserDefaults.standard.set(d, forKey: thermalKey)
        }
        // Auto-tag ExperimentLabStore today
        let exp = ExperimentLabStore.shared
        if modality.contains("Sauna") && !exp.dailyTagsToday.contains("sauna") {
            exp.toggleJournalTag("sauna")
        }
        if modality.contains("Cold") && !exp.dailyTagsToday.contains("cold_plunge") {
            exp.toggleJournalTag("cold_plunge")
        }
    }

    public func logNBackSession(nLevel: Int, trials: Int, accuracyPct: Int) {
        let rec = NBackSessionRecord(id: UUID(), date: Date(), nLevel: nLevel, trials: trials, accuracyPct: accuracyPct)
        nBackSessions.insert(rec, at: 0)
        nBackSessions = Array(nBackSessions.prefix(40))
        if let d = try? JSONEncoder().encode(nBackSessions) {
            UserDefaults.standard.set(d, forKey: nbackKey)
        }
    }

    public func logMewingSession(minutes: Double) {
        let rec = MewingSessionRecord(id: UUID(), date: Date(), durationMinutes: (minutes * 10).rounded() / 10)
        mewingSessions.insert(rec, at: 0)
        mewingSessions = Array(mewingSessions.prefix(40))
        if let d = try? JSONEncoder().encode(mewingSessions) {
            UserDefaults.standard.set(d, forKey: mewingKey)
        }
    }

    public func saveDecathlon(_ state: DecathlonBenchmarkState) {
        var copy = state
        copy.updatedAt = Date()
        decathlon = copy
        if let d = try? JSONEncoder().encode(copy) {
            UserDefaults.standard.set(d, forKey: decathlonKey)
        }
    }

    private func load() {
        if let d = UserDefaults.standard.data(forKey: thermalKey),
           let dec = try? JSONDecoder().decode([ThermalSessionRecord].self, from: d) {
            thermalSessions = dec
        }
        if let d = UserDefaults.standard.data(forKey: nbackKey),
           let dec = try? JSONDecoder().decode([NBackSessionRecord].self, from: d) {
            nBackSessions = dec
        }
        if let d = UserDefaults.standard.data(forKey: mewingKey),
           let dec = try? JSONDecoder().decode([MewingSessionRecord].self, from: d) {
            mewingSessions = dec
        }
        if let d = UserDefaults.standard.data(forKey: decathlonKey),
           let dec = try? JSONDecoder().decode(DecathlonBenchmarkState.self, from: d) {
            decathlon = dec
        }
    }
}

// MARK: - Realtime Stereo Binaural Audio Synthesizer (AVAudioEngine + AVAudioSourceNode)
private struct BinauralSynthParams {
    var carrierHz: Double = 200.0
    var beatHz: Double = 6.0
    var gain: Float = 0.14
    var phaseL: Double = 0
    var phaseR: Double = 0
}

private final class BinauralAudioEngine: @unchecked Sendable {
    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private let lock = OSAllocatedUnfairLock(initialState: BinauralSynthParams())

    func start(carrierHz: Double = 200.0, beatHz: Double) {
        stop()
        lock.withLock {
            $0.carrierHz = carrierHz
            $0.beatHz = beatHz
            $0.phaseL = 0
            $0.phaseR = 0
        }

        let eng = AVAudioEngine()
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        let sr = format.sampleRate
        let stateLock = self.lock

        let node = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let params = stateLock.withLock { p -> (Double, Double, Float, Double, Double) in
                return (p.carrierHz, p.beatHz, p.gain, p.phaseL, p.phaseR)
            }
            let incL = 2.0 * .pi * params.0 / sr
            let incR = 2.0 * .pi * (params.0 + params.1) / sr
            var pL = params.3
            var pR = params.4
            let gain = params.2

            for frame in 0..<Int(frameCount) {
                let sL = Float(sin(pL)) * gain
                let sR = Float(sin(pR)) * gain
                pL += incL
                pR += incR
                if pL > 2.0 * .pi { pL -= 2.0 * .pi }
                if pR > 2.0 * .pi { pR -= 2.0 * .pi }

                if abl.count >= 2 {
                    abl[0].mData?.assumingMemoryBound(to: Float.self)[frame] = sL
                    abl[1].mData?.assumingMemoryBound(to: Float.self)[frame] = sR
                } else if abl.count == 1 {
                    abl[0].mData?.assumingMemoryBound(to: Float.self)[frame] = (sL + sR) * 0.5
                }
            }
            let nextPL = pL
            let nextPR = pR
            stateLock.withLock {
                $0.phaseL = nextPL
                $0.phaseR = nextPR
            }
            return noErr
        }

        eng.attach(node)
        eng.connect(node, to: eng.mainMixerNode, format: format)
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        do {
            try eng.start()
            self.engine = eng
            self.sourceNode = node
        } catch {
            self.engine = nil
        }
    }

    func updateBeatHz(_ beatHz: Double) {
        lock.withLock { $0.beatHz = beatHz }
    }

    func stop() {
        engine?.stop()
        engine = nil
        sourceNode = nil
    }
}

// MARK: - Main Thermal, Sound NSDR, Oral Posture, N-Back & Decathlon Suite Sheet
public struct ThermalAndBrainSuiteSheet: View {
    public enum TabMode: String, CaseIterable, Identifiable {
        case thermal = "Thermal"
        case sound = "NSDR"
        case nback = "N-Back"
        case decathlon = "Decathlon"
        public var id: String { rawValue }
    }

    @ObservedObject private var store = ThermalBrainStore.shared
    @ObservedObject private var health = HealthKitManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: TabMode

    public init(initialTab: TabMode = .thermal) {
        _selectedTab = State(initialValue: initialTab)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Suite", selection: $selectedTab) {
                    ForEach(TabMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        switch selectedTab {
                        case .thermal:
                            ThermalExposureSubView()
                        case .sound:
                            BinauralNSDRSubView()
                        case .nback:
                            DualNBackSubView()
                        case .decathlon:
                            DecathlonBenchmarksSubView()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
            }
            .background(ApexTheme.background.ignoresSafeArea())
            .navigationTitle("Thermal, Sound & Brain")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 1. Sauna & Cold Plunge Timer + Oral Mewing Timer
private struct ThermalExposureSubView: View {
    @ObservedObject private var store = ThermalBrainStore.shared
    @State private var modality: String = "Finnish Sauna"
    @State private var targetMinutes: Int = 15
    @State private var tempC: Double = 88
    @State private var isRunning = false
    @State private var elapsedSeconds = 0
    @State private var isMewingRunning = false
    @State private var mewingSeconds = 0

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Thermal Contrast Timer")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Auto-tags Sauna / Cold Plunge in Experiment Lab")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: modality.contains("Cold") ? "snowflake" : "flame.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(modality.contains("Cold") ? ApexTheme.standCyan : ApexTheme.accentAmber)
                }

                Picker("Protocol", selection: $modality) {
                    Text("Sauna").tag("Finnish Sauna")
                    Text("Cold Plunge").tag("Cold Plunge")
                    Text("Contrast").tag("Contrast Cycle")
                }
                .pickerStyle(.segmented)
                .disabled(isRunning)
                .onChange(of: modality) { _, m in
                    if m == "Cold Plunge" { targetMinutes = 3; tempC = 8 }
                    else if m == "Finnish Sauna" { targetMinutes = 15; tempC = 88 }
                    else { targetMinutes = 18; tempC = 85 }
                }

                Stepper("Target: \(targetMinutes) min · \(Int(tempC))°C", value: $targetMinutes, in: 1...45)
                    .disabled(isRunning)
                Slider(value: $tempC, in: 2...105, step: 1)
                    .tint(modality.contains("Cold") ? ApexTheme.standCyan : ApexTheme.accentAmber)
                    .disabled(isRunning)

                let rem = max(0, targetMinutes * 60 - elapsedSeconds)
                Text(String(format: "%02d:%02d", rem / 60, rem % 60))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .center)

                Button {
                    if isRunning {
                        finishThermal()
                    } else {
                        elapsedSeconds = 0
                        isRunning = true
                        Haptics.tap(.medium)
                    }
                } label: {
                    Text(isRunning ? "Complete & Save Session" : "Start Thermal Session")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isRunning ? ApexTheme.exerciseLime : (modality.contains("Cold") ? ApexTheme.standCyan : ApexTheme.accentAmber))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                HStack {
                    Text("7d Sauna: \(Int(store.weeklySaunaMinutes)) min")
                    Spacer()
                    Text("7d Cold: \(Int(store.weeklyColdMinutes)) min")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            }
            .appleCard(padding: 18, cornerRadius: 22)

            // Oral Posture / Mewing Timer Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Oral Posture / Mewing Focus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Suction tongue hold · nasal breathing · lips sealed")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(store.mewingSessions.count) logs")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ApexTheme.standCyan)
                }

                HStack {
                    Text(String(format: "%02d:%02d", mewingSeconds / 60, mewingSeconds % 60))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(ApexTheme.standCyan)
                    Spacer()
                    Button(isMewingRunning ? "Stop & Log" : "Start Timer") {
                        if isMewingRunning {
                            isMewingRunning = false
                            if mewingSeconds >= 30 {
                                store.logMewingSession(minutes: Double(mewingSeconds) / 60.0)
                                Haptics.success()
                            }
                            mewingSeconds = 0
                        } else {
                            mewingSeconds = 0
                            isMewingRunning = true
                            Haptics.tap()
                        }
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(ApexTheme.accentVolt)
                    .clipShape(Capsule())
                }
            }
            .appleCard(padding: 16, cornerRadius: 20)
        }
        .onReceive(ticker) { _ in
            if isRunning {
                elapsedSeconds += 1
                if elapsedSeconds >= targetMinutes * 60 {
                    finishThermal()
                }
            }
            if isMewingRunning {
                mewingSeconds += 1
            }
        }
    }

    private func finishThermal() {
        isRunning = false
        let mins = max(0.5, Double(elapsedSeconds) / 60.0)
        if elapsedSeconds >= 15 {
            store.logThermalSession(modality: modality, minutes: mins, temperatureC: tempC)
            Haptics.success()
        }
        elapsedSeconds = 0
    }
}

// MARK: - 2. 10-Min NSDR + Dual-Sine Binaural Sound Engine
private struct BinauralNSDRSubView: View {
    @ObservedObject private var health = HealthKitManager.shared
    @State private var synth = BinauralAudioEngine()
    @State private var beatHz: Double = 6.0
    @State private var targetMins: Int = 10
    @State private var remainingSeconds: Int = 600
    @State private var isPlaying = false
    @State private var savedBanner: String? = nil

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let presets: [(name: String, hz: Double, desc: String)] = [
        ("NSDR Theta", 6.0, "200Hz L / 206Hz R · Dopamine & parasympathetic reset"),
        ("Alpha Calm", 10.0, "200Hz L / 210Hz R · Relaxed wakeful cognition"),
        ("Gamma Focus", 40.0, "200Hz L / 240Hz R · High-alertness cognitive lock-in")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Binaural NSDR Synthesizer")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Text("Real-time AVAudioSourceNode stereo sine carrier (wear headphones for hemispheric beat).")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                ForEach(presets, id: \.hz) { p in
                    let active = abs(beatHz - p.hz) < 0.1
                    Button {
                        beatHz = p.hz
                        if isPlaying { synth.updateBeatHz(p.hz) }
                        Haptics.selection()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text(p.desc)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if active {
                                Image(systemName: "waveform.circle.fill")
                                    .foregroundStyle(ApexTheme.standCyan)
                            }
                        }
                        .padding(12)
                        .background(active ? ApexTheme.elevatedSurface : ApexTheme.background.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Stepper("Session Timer: \(targetMins) min", value: $targetMins, in: 3...30, step: 1)
                    .disabled(isPlaying)
                    .onChange(of: targetMins) { _, v in remainingSeconds = v * 60 }

                Text(String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ApexTheme.standCyan)
                    .frame(maxWidth: .infinity, alignment: .center)

                Button {
                    if isPlaying {
                        stopAndSave()
                    } else {
                        remainingSeconds = targetMins * 60
                        isPlaying = true
                        synth.start(carrierHz: 200.0, beatHz: beatHz)
                        Haptics.tap(.medium)
                    }
                } label: {
                    Label(isPlaying ? "End & Log NSDR Minutes" : "Play \(Int(beatHz)) Hz Binaural + Timer", systemImage: isPlaying ? "stop.fill" : "headphones")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isPlaying ? ApexTheme.accentAmber : ApexTheme.standCyan)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if let msg = savedBanner {
                    Text(msg)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ApexTheme.accentEmerald)
                }
            }
            .appleCard(padding: 18, cornerRadius: 22)
        }
        .onReceive(ticker) { _ in
            guard isPlaying else { return }
            if remainingSeconds > 1 {
                remainingSeconds -= 1
            } else {
                stopAndSave()
            }
        }
        .onDisappear { synth.stop() }
    }

    private func stopAndSave() {
        synth.stop()
        isPlaying = false
        let elapsedMins = Double(targetMins * 60 - remainingSeconds) / 60.0
        if elapsedMins >= 0.5 {
            Task {
                _ = await health.logMindfulSession(minutes: elapsedMins)
                savedBanner = String(format: "Logged %.1f min NSDR Mindful Session.", elapsedMins)
            }
        }
        remainingSeconds = targetMins * 60
    }
}

// MARK: - 3. Dual N-Back Working Memory Cognitive Trainer
private struct DualNBackSubView: View {
    @ObservedObject private var store = ThermalBrainStore.shared
    @State private var nLevel: Int = 2
    @State private var isPlaying = false
    @State private var trialIndex: Int = 0
    @State private var totalTrials: Int = 20
    @State private var posSequence: [Int] = []
    @State private var letterSequence: [String] = []
    @State private var tappedPosThisTrial = false
    @State private var tappedLetterThisTrial = false
    @State private var hitsAndCorrectRejects: Int = 0
    @State private var lastAccuracy: Int? = nil

    private let letters = ["C", "H", "K", "L", "Q", "R", "S", "T"]
    private let ticker = Timer.publish(every: 2.3, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dual \(nLevel)-Back Cognitive Lab")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Match spatial square OR letter from \(nLevel) steps back")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Stepper("", value: $nLevel, in: 1...3)
                        .labelsHidden()
                        .disabled(isPlaying)
                }

                let activeCell = (isPlaying && trialIndex < posSequence.count) ? posSequence[trialIndex] : -1
                let activeLetter = (isPlaying && trialIndex < letterSequence.count) ? letterSequence[trialIndex] : ""

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(0..<9, id: \.self) { idx in
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(activeCell == idx ? ApexTheme.accentVolt : ApexTheme.elevatedSurface)
                                .frame(height: 68)
                            if activeCell == idx {
                                Text(activeLetter)
                                    .font(.system(size: 26, weight: .black, design: .rounded))
                                    .foregroundStyle(.black)
                            }
                        }
                    }
                }

                if isPlaying {
                    HStack {
                        Text("Trial \(min(trialIndex + 1, totalTrials)) / \(totalTrials)")
                            .font(.system(size: 12, weight: .bold).monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    HStack(spacing: 12) {
                        Button {
                            Haptics.tap()
                            tappedPosThisTrial = true
                        } label: {
                            Label("Position Match", systemImage: "square.grid.3x3.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(tappedPosThisTrial ? .black : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(tappedPosThisTrial ? ApexTheme.standCyan : ApexTheme.elevatedSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        Button {
                            Haptics.tap()
                            tappedLetterThisTrial = true
                        } label: {
                            Label("Letter Match", systemImage: "textformat")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(tappedLetterThisTrial ? .black : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(tappedLetterThisTrial ? ApexTheme.exerciseLime : ApexTheme.elevatedSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                } else {
                    if let acc = lastAccuracy {
                        Text("Last Round: \(acc)% Dual \(nLevel)-Back Accuracy")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(acc >= 75 ? ApexTheme.accentEmerald : ApexTheme.accentAmber)
                    }
                    Button {
                        startGame()
                    } label: {
                        Text("Start 20-Trial Dual \(nLevel)-Back")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(ApexTheme.accentVolt)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
            .appleCard(padding: 18, cornerRadius: 22)

            if store.nBackSessions.count >= 2 {
                let chron = Array(store.nBackSessions.prefix(12).reversed())
                VStack(alignment: .leading, spacing: 8) {
                    Text("Working Memory Trend")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Chart(chron) { s in
                        LineMark(x: .value("Date", s.date), y: .value("Accuracy %", s.accuracyPct))
                            .foregroundStyle(ApexTheme.standCyan)
                        PointMark(x: .value("Date", s.date), y: .value("Accuracy %", s.accuracyPct))
                            .foregroundStyle(ApexTheme.accentVolt)
                    }
                    .frame(height: 110)
                }
                .appleCard(padding: 16, cornerRadius: 20)
            }
        }
        .onReceive(ticker) { _ in
            guard isPlaying else { return }
            scoreCurrentTrial()
            tappedPosThisTrial = false
            tappedLetterThisTrial = false
            if trialIndex + 1 < totalTrials {
                trialIndex += 1
            } else {
                finishGame()
            }
        }
    }

    private func startGame() {
        posSequence = []
        letterSequence = []
        for i in 0..<totalTrials {
            let forcePosMatch = i >= nLevel && Int.random(in: 0..<100) < 28
            let forceLetMatch = i >= nLevel && Int.random(in: 0..<100) < 28
            posSequence.append(forcePosMatch ? posSequence[i - nLevel] : Int.random(in: 0..<9))
            letterSequence.append(forceLetMatch ? letterSequence[i - nLevel] : letters.randomElement()!)
        }
        trialIndex = 0
        hitsAndCorrectRejects = 0
        tappedPosThisTrial = false
        tappedLetterThisTrial = false
        lastAccuracy = nil
        isPlaying = true
        Haptics.tap(.medium)
    }

    private func scoreCurrentTrial() {
        let canCompare = trialIndex >= nLevel
        let isPosMatch = canCompare && posSequence[trialIndex] == posSequence[trialIndex - nLevel]
        let isLetMatch = canCompare && letterSequence[trialIndex] == letterSequence[trialIndex - nLevel]
        if tappedPosThisTrial == isPosMatch { hitsAndCorrectRejects += 1 }
        if tappedLetterThisTrial == isLetMatch { hitsAndCorrectRejects += 1 }
    }

    private func finishGame() {
        isPlaying = false
        let maxPoints = totalTrials * 2
        let acc = max(0, min(100, Int((Double(hitsAndCorrectRejects) / Double(maxPoints) * 100.0).rounded())))
        lastAccuracy = acc
        store.logNBackSession(nLevel: nLevel, trials: totalTrials, accuracyPct: acc)
        Haptics.success()
    }
}

// MARK: - 4. Centenarian Decathlon Functional Longevity Benchmarks
private struct DecathlonBenchmarksSubView: View {
    @ObservedObject private var store = ThermalBrainStore.shared
    @AppStorage(ApexUnitPreferences.unitKey) private var unitRaw: String = ApexUnitSystem.metric.rawValue
    @State private var draft: DecathlonBenchmarkState = ThermalBrainStore.shared.decathlon
    @State private var saved = false

    var body: some View {
        let _ = unitRaw
        let unitLabel = ApexUnitPreferences.weightUnitLabel
        let gripBinding = Binding<Double>(
            get: { (ApexUnitPreferences.weightValue(kg: draft.gripStrengthKg) * 10).rounded() / 10 },
            set: { draft.gripStrengthKg = max(0, ApexUnitPreferences.kgFromWeightInput($0)) }
        )

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Centenarian Decathlon Benchmarks")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Text("Track functional strength, balance & grip standards required to maintain physical independence at age 90+.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                metricRow("Dead Hang Hold (sec · Target 90s+)", value: $draft.deadHangSec)
                metricRow("Dominant Grip (\(unitLabel) · Target \(ApexUnitPreferences.isImperial ? "110+ lbs" : "50+ kg"))", value: gripBinding)
                metricRow("Farmer's Carry Ratio (×BW · Target 1.0x)", value: $draft.farmersCarryBwRatio)
                metricRow("Wall Sit Hold (sec · Target 120s)", value: $draft.wallSitSec)
                metricRow("1-Leg Balance Eyes Closed (sec · Target 25s)", value: $draft.singleLegEyesClosedSec)
                metricRow("Broad / Vertical Jump (cm)", value: $draft.verticalJumpCm)

                Stepper("Sit-to-Stand Floor Score: \(draft.floorGetUpScore) / 10", value: $draft.floorGetUpScore, in: 0...10)
                Stepper("Strict Push-ups Capacity: \(draft.maxPushups)", value: $draft.maxPushups, in: 0...100)

                Button {
                    store.saveDecathlon(draft)
                    saved = true
                    Haptics.success()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { saved = false }
                } label: {
                    Text(saved ? "Benchmarks Saved ✓" : "Save Decathlon Benchmarks")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(saved ? ApexTheme.accentEmerald : ApexTheme.accentVolt)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .appleCard(padding: 18, cornerRadius: 22)
        }
    }

    private func metricRow(_ label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.white)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .frame(width: 72, height: 34)
                .padding(.horizontal, 8)
                .background(ApexTheme.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
