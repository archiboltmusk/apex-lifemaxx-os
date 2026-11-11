import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Streaming Apple Health export.xml Importer

public struct HealthXMLImportSummary: Equatable {
    public let recordsScanned: Int
    public let matchedRecords: Int
    public let hrvDays: Int
    public let rhrDays: Int
    public let sleepDays: Int
    public let moveDays: Int
    public let weightDays: Int
    public let vo2Days: Int
    public let latestGlucoseMgDl: Double?
}

public final class HealthExportXMLParser: NSObject, XMLParserDelegate {
    private let cutoffDayKey: String
    private let calendar: Calendar

    public var recordsScanned: Int = 0
    public var matchedRecords: Int = 0

    // Daily buckets keyed by "YYYY-MM-DD"
    private var hrvByDay: [String: (sum: Double, count: Int)] = [:]
    private var rhrByDay: [String: (sum: Double, count: Int)] = [:]
    private var vo2ByDay: [String: (sum: Double, count: Int)] = [:]
    private var weightByDay: [String: (sum: Double, count: Int)] = [:]
    // Active energy keyed by day -> sourceName -> kcal (prevents Watch + Phone double-counting)
    private var moveByDaySource: [String: [String: Double]] = [:]

    // Latest point-in-time vitals tracked by full timestamp prefix
    private var latestBodyFat: (ts: String, val: Double)?
    private var latestSpO2: (ts: String, val: Double)?
    private var latestResp: (ts: String, val: Double)?
    private var latestGlucose: (ts: String, val: Double)?

    // Sleep intervals assigned to wakeup day key ("YYYY-MM-DD")
    private struct Interval: Comparable {
        let start: TimeInterval
        let end: TimeInterval
        static func < (lhs: Interval, rhs: Interval) -> Bool { lhs.start < rhs.start }
    }
    private var deepIntervalsByDay: [String: [Interval]] = [:]
    private var remIntervalsByDay: [String: [Interval]] = [:]
    private var coreIntervalsByDay: [String: [Interval]] = [:]
    private var awakeIntervalsByDay: [String: [Interval]] = [:]

    public var progressHandler: ((Int) -> Void)?

    public init(lookbackDays: Int = 90) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        self.calendar = cal
        let cutoff = cal.date(byAdding: .day, value: -lookbackDays, to: Date()) ?? Date()
        let comps = cal.dateComponents([.year, .month, .day], from: cutoff)
        self.cutoffDayKey = String(
            format: "%04d-%02d-%02d",
            comps.year ?? 2020, comps.month ?? 1, comps.day ?? 1
        )
        super.init()
    }

    public func parse(url: URL) throws -> HealthXMLImportSummary {
        guard let parser = XMLParser(contentsOf: url) else {
            throw NSError(
                domain: "HealthExportXMLParser",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to open XML stream from file."]
            )
        }
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else {
            throw parser.parserError ?? NSError(
                domain: "HealthExportXMLParser",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Malformed Apple Health XML structure."]
            )
        }
        return buildSummary()
    }

    public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        guard elementName == "Record", let type = attributeDict["type"] else { return }
        recordsScanned += 1
        if recordsScanned % 25_000 == 0 {
            progressHandler?(recordsScanned)
        }

        guard let startStr = attributeDict["startDate"], startStr.count >= 19 else { return }
        let endStr = attributeDict["endDate"] ?? startStr
        let endDayKey = String(endStr.prefix(10))
        guard endDayKey >= cutoffDayKey else { return }
        let dayKey = String(startStr.prefix(10))
        let tsKey = String(endStr.prefix(19))

        switch type {
        case "HKQuantityTypeIdentifierHeartRateVariabilitySDNN":
            guard let val = Double(attributeDict["value"] ?? ""), val > 0, val < 300 else { return }
            let cur = hrvByDay[dayKey] ?? (0, 0)
            hrvByDay[dayKey] = (cur.sum + val, cur.count + 1)
            matchedRecords += 1

        case "HKQuantityTypeIdentifierRestingHeartRate":
            guard let val = Double(attributeDict["value"] ?? ""), val >= 25, val <= 160 else { return }
            let cur = rhrByDay[dayKey] ?? (0, 0)
            rhrByDay[dayKey] = (cur.sum + val, cur.count + 1)
            matchedRecords += 1

        case "HKQuantityTypeIdentifierVO2Max":
            guard let val = Double(attributeDict["value"] ?? ""), val >= 10, val <= 100 else { return }
            let cur = vo2ByDay[dayKey] ?? (0, 0)
            vo2ByDay[dayKey] = (cur.sum + val, cur.count + 1)
            matchedRecords += 1

        case "HKQuantityTypeIdentifierBodyMass":
            guard var val = Double(attributeDict["value"] ?? ""), val > 0 else { return }
            if (attributeDict["unit"] ?? "kg").lowercased().contains("lb") {
                val *= 0.45359237
            }
            guard val >= 25, val <= 300 else { return }
            let cur = weightByDay[dayKey] ?? (0, 0)
            weightByDay[dayKey] = (cur.sum + val, cur.count + 1)
            matchedRecords += 1

        case "HKQuantityTypeIdentifierBodyFatPercentage":
            guard var val = Double(attributeDict["value"] ?? ""), val > 0 else { return }
            if val <= 1.0 { val *= 100.0 }
            guard val >= 2, val <= 70 else { return }
            if latestBodyFat == nil || tsKey >= latestBodyFat!.ts {
                latestBodyFat = (tsKey, val)
            }
            matchedRecords += 1

        case "HKQuantityTypeIdentifierActiveEnergyBurned":
            guard var val = Double(attributeDict["value"] ?? ""), val > 0 else { return }
            if (attributeDict["unit"] ?? "kcal").lowercased() == "kj" {
                val /= 4.184
            }
            let src = attributeDict["sourceName"] ?? "Health"
            var daySources = moveByDaySource[dayKey] ?? [:]
            daySources[src, default: 0] += val
            moveByDaySource[dayKey] = daySources
            matchedRecords += 1

        case "HKQuantityTypeIdentifierOxygenSaturation":
            guard var val = Double(attributeDict["value"] ?? ""), val > 0 else { return }
            if val <= 1.0 { val *= 100.0 }
            guard val >= 70, val <= 100 else { return }
            if latestSpO2 == nil || tsKey >= latestSpO2!.ts {
                latestSpO2 = (tsKey, val)
            }
            matchedRecords += 1

        case "HKQuantityTypeIdentifierRespiratoryRate":
            guard let val = Double(attributeDict["value"] ?? ""), val >= 4, val <= 60 else { return }
            if latestResp == nil || tsKey >= latestResp!.ts {
                latestResp = (tsKey, val)
            }
            matchedRecords += 1

        case "HKQuantityTypeIdentifierBloodGlucose":
            guard var val = Double(attributeDict["value"] ?? ""), val > 0 else { return }
            if (attributeDict["unit"] ?? "mg/dL").lowercased().contains("mmol") {
                val *= 18.0182
            }
            guard val >= 30, val <= 600 else { return }
            if latestGlucose == nil || tsKey >= latestGlucose!.ts {
                latestGlucose = (tsKey, val)
            }
            matchedRecords += 1

        case "HKCategoryTypeIdentifierSleepAnalysis":
            guard let sleepValue = attributeDict["value"],
                  let sSec = parseTimestampEpoch(startStr),
                  let eSec = parseTimestampEpoch(endStr),
                  eSec > sSec else { return }
            let wakeDay = wakeDayKey(endDateStr: endStr)
            let span = Interval(start: sSec, end: eSec)
            if sleepValue.contains("AsleepDeep") {
                deepIntervalsByDay[wakeDay, default: []].append(span)
                matchedRecords += 1
            } else if sleepValue.contains("AsleepREM") {
                remIntervalsByDay[wakeDay, default: []].append(span)
                matchedRecords += 1
            } else if sleepValue.contains("AsleepCore")
                        || sleepValue.contains("AsleepUnspecified")
                        || sleepValue == "HKCategoryValueSleepAnalysisAsleep" {
                coreIntervalsByDay[wakeDay, default: []].append(span)
                matchedRecords += 1
            } else if sleepValue.contains("Awake") {
                awakeIntervalsByDay[wakeDay, default: []].append(span)
                matchedRecords += 1
            }

        default:
            break
        }
    }

    private func buildSummary() -> HealthXMLImportSummary {
        func points(from dict: [String: (sum: Double, count: Int)]) -> [DailyMetricPoint] {
            dict.keys.sorted().compactMap { key in
                guard let date = parseDayDate(key), let entry = dict[key], entry.count > 0 else { return nil }
                return DailyMetricPoint(date: date, value: entry.sum / Double(entry.count))
            }
        }

        let hrvPoints = points(from: hrvByDay)
        let rhrPoints = points(from: rhrByDay)
        let vo2Points = points(from: vo2ByDay)
        let weightPoints = points(from: weightByDay)

        let movePoints: [DailyMetricPoint] = moveByDaySource.keys.sorted().compactMap { key in
            guard let date = parseDayDate(key), let sources = moveByDaySource[key] else { return nil }
            // Prefer Watch active energy if present, else highest single-source total so devices don't stack.
            let watchVal = sources.first(where: { $0.key.lowercased().contains("watch") })?.value
            let bestVal = watchVal ?? sources.values.max() ?? 0
            guard bestVal > 0 else { return nil }
            return DailyMetricPoint(date: date, value: bestVal)
        }

        let allSleepDays = Set(deepIntervalsByDay.keys)
            .union(remIntervalsByDay.keys)
            .union(coreIntervalsByDay.keys)
            .sorted()

        var sleepPoints: [DailyMetricPoint] = []
        var latestSleep: (deep: Double, rem: Double, core: Double, awake: Double, total: Double)?
        for key in allSleepDays {
            guard let date = parseDayDate(key) else { continue }
            let deep = mergedHours(deepIntervalsByDay[key] ?? [])
            let rem = mergedHours(remIntervalsByDay[key] ?? [])
            let core = mergedHours(coreIntervalsByDay[key] ?? [])
            let awake = mergedHours(awakeIntervalsByDay[key] ?? [])
            let total = deep + rem + core
            guard total > 0.25 else { continue }
            sleepPoints.append(DailyMetricPoint(date: date, value: total))
            latestSleep = (deep, rem, core, awake, total)
        }

        DispatchQueue.main.async {
            HealthKitManager.shared.applyImportedAppleHealthSnapshot(
                hrvPoints: hrvPoints,
                rhrPoints: rhrPoints,
                vo2Points: vo2Points,
                sleepPoints: sleepPoints,
                movePoints: movePoints,
                weightPoints: weightPoints,
                latestHRV: hrvPoints.last?.value,
                latestRHR: rhrPoints.last?.value,
                latestVO2: vo2Points.last?.value,
                latestWeightKg: weightPoints.last?.value,
                latestBodyFatPct: self.latestBodyFat?.val,
                latestSleepHours: latestSleep?.total,
                latestDeepHours: latestSleep?.deep,
                latestRemHours: latestSleep?.rem,
                latestCoreHours: latestSleep?.core,
                latestAwakeHours: latestSleep?.awake,
                latestSpO2: self.latestSpO2?.val,
                latestRespRate: self.latestResp?.val,
                latestGlucoseMgDl: self.latestGlucose?.val
            )
        }

        return HealthXMLImportSummary(
            recordsScanned: recordsScanned,
            matchedRecords: matchedRecords,
            hrvDays: hrvPoints.count,
            rhrDays: rhrPoints.count,
            sleepDays: sleepPoints.count,
            moveDays: movePoints.count,
            weightDays: weightPoints.count,
            vo2Days: vo2Points.count,
            latestGlucoseMgDl: latestGlucose?.val
        )
    }

    private func mergedHours(_ intervals: [Interval]) -> Double {
        guard !intervals.isEmpty else { return 0 }
        let sorted = intervals.sorted()
        var totalSec: TimeInterval = 0
        var curStart = sorted[0].start
        var curEnd = sorted[0].end
        for span in sorted.dropFirst() {
            if span.start <= curEnd {
                curEnd = max(curEnd, span.end)
            } else {
                totalSec += (curEnd - curStart)
                curStart = span.start
                curEnd = span.end
            }
        }
        totalSec += (curEnd - curStart)
        return min(18.0, totalSec / 3600.0)
    }

    private func wakeDayKey(endDateStr: String) -> String {
        // Assign sleep ending after 12:00 noon to today, or early afternoon naps still stay on endDayKey.
        String(endDateStr.prefix(10))
    }

    private func parseDayDate(_ key: String) -> Date? {
        let parts = key.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              let d = Int(parts[2]) else { return nil }
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))
    }

    private func parseTimestampEpoch(_ raw: String) -> TimeInterval? {
        // Fast ASCII parse for "YYYY-MM-DD HH:MM:SS"
        guard raw.count >= 19 else { return nil }
        let utf8 = Array(raw.utf8)
        func digits(_ start: Int, _ len: Int) -> Int? {
            var acc = 0
            for i in start..<(start + len) {
                let c = Int(utf8[i]) - 48
                guard c >= 0, c <= 9 else { return nil }
                acc = acc * 10 + c
            }
            return acc
        }
        guard let y = digits(0, 4),
              let mo = digits(5, 2),
              let d = digits(8, 2),
              let h = digits(11, 2),
              let mi = digits(14, 2),
              let s = digits(17, 2) else { return nil }
        return calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))?.timeIntervalSince1970
    }
}

// MARK: - Native SwiftUI Sheet for On-Device Apple Health XML Import

public struct HealthXMLImportSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var showFileImporter: Bool = false
    @State private var isParsing: Bool = false
    @State private var scannedProgress: Int = 0
    @State private var summary: HealthXMLImportSummary?
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "heart.text.square.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(ApexTheme.moveCrimson)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Apple Health XML Import")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("100% On-Device Streaming Parser (No Mac Required)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text("Import up to 90 days of HRV, Resting HR, Sleep Stages, Active Energy, Body Mass, VO₂ Max, SpO₂, Respiratory Rate, and Blood Glucose directly from your Apple Health export.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .appleCard(padding: 16, cornerRadius: 18)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("HOW TO EXPORT ON IPHONE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(ApexTheme.standCyan)
                            .tracking(0.8)

                        stepRow(num: "1", text: "Open the Apple Health app → tap your Profile picture → Export All Health Data.")
                        stepRow(num: "2", text: "Save `export.zip` to the iOS Files app.")
                        stepRow(num: "3", text: "Tap `export.zip` once in Files to unzip `apple_health_export`, then select `export.xml` below.")
                    }
                    .appleCard(padding: 16, cornerRadius: 18)

                    if isParsing {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(ApexTheme.accentVolt)
                                .scaleEffect(1.2)
                            Text("Streaming Apple Health XML… \(scannedProgress.formatted()) records scanned")
                                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .appleCard(padding: 20, cornerRadius: 18)
                    }

                    if let errorMessage {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(ApexTheme.accentAmber)
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundStyle(.white)
                        }
                        .appleCard(padding: 14, cornerRadius: 16)
                    }

                    if let summary {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(ApexTheme.accentEmerald)
                                Text("Imported to APEX Health Engine")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                metricBox(label: "Records Scanned", value: "\(summary.recordsScanned.formatted())")
                                metricBox(label: "HRV / RHR Days", value: "\(summary.hrvDays)d / \(summary.rhrDays)d")
                                metricBox(label: "Sleep / Move", value: "\(summary.sleepDays)d / \(summary.moveDays)d")
                                metricBox(label: "Weight / VO₂", value: "\(summary.weightDays)d / \(summary.vo2Days)d")
                            }
                            if let g = summary.latestGlucoseMgDl {
                                Text("Latest Blood Glucose imported: \(ApexUnitPreferences.formatGlucose(mgDl: g))")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(ApexTheme.accentEmerald)
                            }
                        }
                        .appleCard(padding: 16, cornerRadius: 18)
                    }

                    Button {
                        Haptics.tap(.medium)
                        errorMessage = nil
                        showFileImporter = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.badge.plus")
                            Text(isParsing ? "Importing…" : "Choose Apple Health export.xml")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(ApexTheme.accentVolt)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isParsing)
                }
                .padding(16)
            }
            .background(ApexTheme.background.ignoresSafeArea())
            .navigationTitle("Health XML Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.xml, .zip],
                allowsMultipleSelection: false
            ) { result in
                handlePickedFile(result)
            }
        }
    }

    private func stepRow(num: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(num)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.black)
                .frame(width: 20, height: 20)
                .background(ApexTheme.accentVolt, in: Circle())
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private func metricBox(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(ApexTheme.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func handlePickedFile(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let err):
            errorMessage = err.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            if url.pathExtension.lowercased() == "zip" {
                errorMessage = "You selected export.zip. Tap export.zip once inside the iOS Files app to extract it, then open apple_health_export and pick export.xml."
                return
            }
            isParsing = true
            scannedProgress = 0
            summary = nil
            errorMessage = nil

            Task.detached(priority: .userInitiated) {
                let scoped = url.startAccessingSecurityScopedResource()
                defer {
                    if scoped { url.stopAccessingSecurityScopedResource() }
                }
                do {
                    let parser = HealthExportXMLParser(lookbackDays: 90)
                    parser.progressHandler = { count in
                        DispatchQueue.main.async {
                            scannedProgress = count
                        }
                    }
                    let parsed = try parser.parse(url: url)
                    await MainActor.run {
                        summary = parsed
                        isParsing = false
                        Haptics.success()
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        isParsing = false
                    }
                }
            }
        }
    }
}
