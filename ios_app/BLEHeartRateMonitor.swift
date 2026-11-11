import SwiftUI
import Combine
import CoreBluetooth
import WorkoutKit
import HealthKit

// MARK: - CoreBluetooth Chest Strap & Live R-R Monitor (0x180D / 0x2A37)
@MainActor
public final class BLEHeartRateMonitor: NSObject, ObservableObject {
    public static let shared = BLEHeartRateMonitor()

    @Published public private(set) var stateText: String = "Idle"
    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var deviceName: String? = nil
    @Published public private(set) var liveBPM: Int? = nil
    @Published public private(set) var liveRMSSD: Double? = nil
    @Published public private(set) var peakBPM: Int = 0
    @Published public private(set) var recoveryTimerRemaining: Int = 0
    @Published public private(set) var hrr60DropBpm: Int? = nil
    @Published public private(set) var discoveredDevices: [DiscoveredStrap] = []

    public struct DiscoveredStrap: Identifiable, Hashable {
        public let id: UUID
        public let name: String
        public let rssi: Int
    }

    private var centralManager: CBCentralManager?
    private var peripheralsById: [UUID: CBPeripheral] = [:]
    private var activePeripheral: CBPeripheral?
    private var rrBufferMs: [Double] = []
    private var recoveryTask: Task<Void, Never>?
    private var recoveryStartBPM: Int?

    private let heartRateServiceUUID = CBUUID(string: "180D")
    private let heartRateMeasurementUUID = CBUUID(string: "2A37")

    private override init() {
        super.init()
    }

    public func startScanning() {
        Haptics.selection()
        discoveredDevices.removeAll()
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: .main)
        }
        guard let cm = centralManager else { return }
        if cm.state == .poweredOn {
            isScanning = true
            stateText = "Scanning for ANT+/BLE chest straps..."
            cm.scanForPeripherals(withServices: [heartRateServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        } else {
            stateText = "Bluetooth preparing..."
            isScanning = true
        }
    }

    public func stopScanning() {
        centralManager?.stopScan()
        isScanning = false
        if !isConnected {
            stateText = discoveredDevices.isEmpty ? "No HR strap paired" : "Select a chest strap"
        }
    }

    public func connect(to strapId: UUID) {
        guard let peripheral = peripheralsById[strapId], let cm = centralManager else { return }
        stopScanning()
        stateText = "Connecting to \(peripheral.name ?? "HR Strap")..."
        peripheral.delegate = self
        activePeripheral = peripheral
        cm.connect(peripheral, options: nil)
    }

    public func disconnect() {
        recoveryTask?.cancel()
        recoveryTask = nil
        recoveryTimerRemaining = 0
        recoveryStartBPM = nil
        if let peripheral = activePeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        activePeripheral = nil
        isConnected = false
        liveBPM = nil
        liveRMSSD = nil
        rrBufferMs.removeAll()
        deviceName = nil
        stateText = "Disconnected"
    }

    public func startHRR60RecoveryCheck() {
        guard let currentBPM = liveBPM ?? (peakBPM > 0 ? peakBPM : nil) else { return }
        Haptics.tap()
        recoveryTask?.cancel()
        recoveryStartBPM = max(currentBPM, peakBPM)
        hrr60DropBpm = nil
        recoveryTimerRemaining = 60

        recoveryTask = Task { [weak self] in
            for sec in stride(from: 59, through: 0, by: -1) {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self else { return }
                    self.recoveryTimerRemaining = sec
                    if sec == 0, let baseline = self.recoveryStartBPM, let endBPM = self.liveBPM {
                        let drop = max(0, baseline - endBPM)
                        self.hrr60DropBpm = drop
                        Haptics.success()
                        let rhrRMSSD = self.liveRMSSD
                        Task {
                            await HealthKitManager.shared.saveHeartRateToHealth(
                                bpm: Double(endBPM),
                                hrvMs: rhrRMSSD
                            )
                        }
                        HealthKitManager.shared.syncEventToMac(extraPayload: [
                            "hrr60DropBpm": drop,
                            "liveChestBPM": endBPM,
                            "liveChestRMSSD": rhrRMSSD ?? 0
                        ])
                    }
                }
            }
        }
    }

    private func parseHeartRatePacket(_ data: Data) {
        let bytes = [UInt8](data)
        guard bytes.count >= 2 else { return }
        let flags = bytes[0]
        let is16BitBPM = (flags & 0x01) != 0
        let hasEnergyExpended = (flags & 0x08) != 0
        let hasRRIntervals = (flags & 0x10) != 0

        var index = 1
        let bpm: Int
        if is16BitBPM {
            guard bytes.count >= index + 2 else { return }
            bpm = Int(UInt16(bytes[index]) | (UInt16(bytes[index + 1]) << 8))
            index += 2
        } else {
            bpm = Int(bytes[index])
            index += 1
        }

        if hasEnergyExpended {
            index += 2
        }

        if hasRRIntervals {
            while index + 1 < bytes.count {
                let rawRR = UInt16(bytes[index]) | (UInt16(bytes[index + 1]) << 8)
                let rrMs = (Double(rawRR) / 1024.0) * 1000.0
                if rrMs > 300 && rrMs < 2000 {
                    rrBufferMs.append(rrMs)
                    if rrBufferMs.count > 30 {
                        rrBufferMs.removeFirst(rrBufferMs.count - 30)
                    }
                }
                index += 2
            }
            if rrBufferMs.count >= 5 {
                var sumSqDiff = 0.0
                for i in 1..<rrBufferMs.count {
                    let diff = rrBufferMs[i] - rrBufferMs[i - 1]
                    sumSqDiff += diff * diff
                }
                let rmssd = sqrt(sumSqDiff / Double(rrBufferMs.count - 1))
                liveRMSSD = (rmssd * 10).rounded() / 10
            }
        }

        liveBPM = bpm
        if bpm > peakBPM { peakBPM = bpm }
    }
}

extension BLEHeartRateMonitor: CBCentralManagerDelegate, CBPeripheralDelegate {
    nonisolated public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        Task { @MainActor in
            switch state {
            case .poweredOn:
                if self.isScanning {
                    self.stateText = "Scanning for ANT+/BLE chest straps..."
                    central.scanForPeripherals(withServices: [self.heartRateServiceUUID], options: nil)
                }
            case .unsupported:
                self.isScanning = false
                self.stateText = "Bluetooth Low Energy unavailable on Simulator"
            case .unauthorized:
                self.isScanning = false
                self.stateText = "Enable Bluetooth in iOS Settings"
            case .poweredOff:
                self.isScanning = false
                self.stateText = "Bluetooth is turned off"
            default:
                self.stateText = "Bluetooth unavailable"
            }
        }
    }

    nonisolated public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let pid = peripheral.identifier
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? "BLE HR Strap"
        let rssiVal = RSSI.intValue
        Task { @MainActor in
            self.peripheralsById[pid] = peripheral
            if !self.discoveredDevices.contains(where: { $0.id == pid }) {
                self.discoveredDevices.append(DiscoveredStrap(id: pid, name: name, rssi: rssiVal))
                self.stateText = "Found \(self.discoveredDevices.count) HR device(s)"
            }
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let pname = peripheral.name ?? "HR Strap"
        Task { @MainActor in
            self.isConnected = true
            self.deviceName = pname
            self.stateText = "Connected · \(pname)"
            Haptics.success()
            peripheral.discoverServices([self.heartRateServiceUUID])
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            self.isConnected = false
            self.stateText = "Connection failed"
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            self.isConnected = false
            self.liveBPM = nil
            self.stateText = "Strap disconnected"
        }
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == CBUUID(string: "180D") {
            peripheral.discoverCharacteristics([CBUUID(string: "2A37")], for: service)
        }
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let chars = service.characteristics else { return }
        for char in chars where char.uuid == CBUUID(string: "2A37") {
            peripheral.setNotifyValue(true, for: char)
        }
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == CBUUID(string: "2A37"), let data = characteristic.value else { return }
        Task { @MainActor in
            self.parseHeartRatePacket(data)
        }
    }
}

// MARK: - WorkoutKit Apple Watch Protocol Scheduler
@MainActor
public final class WatchWorkoutScheduler: ObservableObject {
    public static let shared = WatchWorkoutScheduler()

    @Published public private(set) var isScheduling: Bool = false
    @Published public private(set) var statusMessage: String? = nil
    @Published public private(set) var scheduledTitles: [String] = []

    private init() {}

    public func pushStrengthProtocolToWatch(title: String, durationMinutes: Int = 35, activity: HKWorkoutActivityType = .traditionalStrengthTraining) async {
        isScheduling = true
        statusMessage = nil
        Haptics.tap()

        let workMinutes = max(10, durationMinutes - 8)
        let warmupStep = WorkoutStep(goal: .time(5, .minutes))
        let workBlock = IntervalBlock(
            steps: [
                IntervalStep(.work, goal: .time(Double(workMinutes), .minutes)),
                IntervalStep(.recovery, goal: .time(2, .minutes))
            ],
            iterations: 1
        )
        let cooldownStep = WorkoutStep(goal: .time(3, .minutes))
        let customWorkout = CustomWorkout(
            activity: activity,
            location: .indoor,
            displayName: title,
            warmup: warmupStep,
            blocks: [workBlock],
            cooldown: cooldownStep
        )
        let plan = WorkoutPlan(.custom(customWorkout))

        let auth = await WorkoutScheduler.shared.requestAuthorization()
        guard auth == .authorized else {
            isScheduling = false
            statusMessage = "WorkoutKit permission not authorized on this device."
            return
        }

        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .minute, value: 2, to: Date()) ?? Date()
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: targetDate)
        comps.calendar = calendar

        await WorkoutScheduler.shared.schedule(plan, at: comps)
        if !scheduledTitles.contains(title) {
            scheduledTitles.insert(title, at: 0)
        }
        isScheduling = false
        statusMessage = "Pushed \"\(title)\" (5m Warmup · \(workMinutes)m Work · 3m Cooldown) to Apple Watch."
        Haptics.success()
    }
}

// MARK: - Sheet UI for Chest Strap + Watch WorkoutKit
public struct ChestStrapWatchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var ble = BLEHeartRateMonitor.shared
    @ObservedObject private var scheduler = WatchWorkoutScheduler.shared

    let activeWorkoutTitle: String

    public init(activeWorkoutTitle: String) {
        self.activeWorkoutTitle = activeWorkoutTitle
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    watchCard
                    bleCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(ApexTheme.bg.ignoresSafeArea())
            .navigationTitle("Watch & HR Strap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var watchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Apple Watch Push", systemImage: "applewatch.radiowaves.left.and.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(ApexTheme.green)
                Spacer()
                Text("WorkoutKit")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ApexTheme.secondaryText)
            }

            Text("Schedules \(activeWorkoutTitle) directly into your Apple Watch native Workout queue so rings, HR zones, and haptics stay synced automatically.")
                .font(.subheadline)
                .foregroundStyle(ApexTheme.secondaryText)

            HStack(spacing: 10) {
                Button {
                    Task {
                        await scheduler.pushStrengthProtocolToWatch(title: "\(activeWorkoutTitle) Session", durationMinutes: 35, activity: .traditionalStrengthTraining)
                    }
                } label: {
                    Label(scheduler.isScheduling ? "Scheduling..." : "Push 35m Strength", systemImage: "figure.strengthtraining.traditional")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(ApexTheme.green)
                .disabled(scheduler.isScheduling)

                Button {
                    Task {
                        await scheduler.pushStrengthProtocolToWatch(title: "Zone 2 Aerobic Base", durationMinutes: 40, activity: .running)
                    }
                } label: {
                    Label("Zone 2 · 40m", systemImage: "heart.circle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(ApexTheme.blue)
                .disabled(scheduler.isScheduling)
            }

            if let msg = scheduler.statusMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(ApexTheme.green)
            }
        }
        .padding(18)
        .appleCard(cornerRadius: 20)
    }

    private var bleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("BLE Chest Strap (0x180D)", systemImage: "waveform.path.ecg")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(ApexTheme.red)
                Spacer()
                Text(ble.isConnected ? "Connected" : "Ready")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ble.isConnected ? ApexTheme.green : ApexTheme.secondaryText)
            }

            Text(ble.stateText)
                .font(.caption)
                .foregroundStyle(ApexTheme.secondaryText)

            if ble.isConnected {
                HStack(spacing: 12) {
                    VStack(alignment: .leading) {
                        Text("Live HR")
                            .font(.caption)
                            .foregroundStyle(ApexTheme.secondaryText)
                        Text(ble.liveBPM.map { "\($0) bpm" } ?? "—")
                            .font(.title2.weight(.bold).monospacedDigit())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading) {
                        Text("Live R-R HRV")
                            .font(.caption)
                            .foregroundStyle(ApexTheme.secondaryText)
                        Text(ble.liveRMSSD.map { String(format: "%.0f ms", $0) } ?? "—")
                            .font(.title2.weight(.bold).monospacedDigit())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 6)

                HStack(spacing: 10) {
                    Button {
                        ble.startHRR60RecoveryCheck()
                    } label: {
                        Text(ble.recoveryTimerRemaining > 0 ? "HRR-60: \(ble.recoveryTimerRemaining)s" : "Run 60s HRR Test")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ApexTheme.blue)

                    Button("Disconnect") {
                        ble.disconnect()
                    }
                    .buttonStyle(.bordered)
                    .tint(ApexTheme.red)
                }

                if let drop = ble.hrr60DropBpm {
                    Text("HRR-60 Recovery Drop: -\(drop) bpm")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(drop >= 22 ? ApexTheme.green : ApexTheme.orange)
                }
            } else {
                Button {
                    if ble.isScanning { ble.stopScanning() } else { ble.startScanning() }
                } label: {
                    Label(ble.isScanning ? "Stop Scan" : "Scan Polar / Garmin Strap", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(ApexTheme.blue)

                ForEach(ble.discoveredDevices) { strap in
                    Button {
                        ble.connect(to: strap.id)
                    } label: {
                        HStack {
                            Text(strap.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(strap.rssi) dBm")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(ApexTheme.secondaryText)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(ApexTheme.tertiaryText)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(ApexTheme.cardElevated, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(18)
        .appleCard(cornerRadius: 20)
    }
}
