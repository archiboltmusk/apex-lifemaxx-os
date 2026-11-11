import SwiftUI
import PDFKit
import UIKit
import UniformTypeIdentifiers

// MARK: - Portable Cross-Device Snapshot (.apexbackup) & Mac Continuity Coordinator
public struct ApexBackupPayload: Codable {
    public let version: Int
    public let exportedAt: Date
    public let deviceName: String
    public let unitSystem: String
    public let chronologicalAge: Double
    public let sleepGoalHours: Double
    public let clinicalPhenoAge: Double?
    public let labPanel: LabBiomarkerPanel?
    public let dailyTagsByDate: [String: [String]]
    public let experimentLogs: [ExperimentLogEntry]
    public let activeProtocolId: String
    public let bestRecords: [String: ExerciseBestRecord]
    public let completedWorkouts: [LoggedStrengthWorkout]
    public let meals: [LoggedFoodEntry]
    public let recipes: [CustomRecipe]
}

@MainActor
public final class ApexBackupCoordinator: ObservableObject {
    public static let shared = ApexBackupCoordinator()

    @Published public var lastBackupStatus: String? = nil
    @Published public var isSyncingBackup: Bool = false

    private let cloudKey = "apex_os_icloud_snapshot_v1"

    private init() {}

    public func buildSnapshot(health: HealthKitManager) -> ApexBackupPayload {
        let strength = StrengthBuilderStore.shared
        let nutrition = NutritionLogStore.shared
        let lab = LabPanelStore.load()

        let expLogs: [ExperimentLogEntry] = {
            guard let data = UserDefaults.standard.data(forKey: "apex_experiment_logs_v1"),
                  let dec = try? JSONDecoder().decode([ExperimentLogEntry].self, from: data) else {
                return []
            }
            return dec
        }()

        // Keep backup lightweight by excluding inline meal thumbnails
        let compactMeals = Array(nutrition.meals.prefix(80)).map { m in
            var copy = m
            copy.photoData = nil
            return copy
        }

        return ApexBackupPayload(
            version: 1,
            exportedAt: Date(),
            deviceName: UIDevice.current.name,
            unitSystem: ApexUnitPreferences.current.rawValue,
            chronologicalAge: health.chronologicalAge,
            sleepGoalHours: health.baselineSleepGoalHours,
            clinicalPhenoAge: health.clinicalPhenoAge,
            labPanel: lab,
            dailyTagsByDate: ExperimentLabStore.shared.dailyTagsByDate,
            experimentLogs: expLogs,
            activeProtocolId: ExperimentLabStore.shared.activeProtocolId,
            bestRecords: strength.bestRecords,
            completedWorkouts: Array(strength.completedWorkouts.prefix(40)),
            meals: compactMeals,
            recipes: nutrition.recipes
        )
    }

    public func encodeSnapshot(health: HealthKitManager) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(buildSnapshot(health: health))
    }

    public func exportBackupFileURL(health: HealthKitManager) -> URL? {
        guard let data = encodeSnapshot(health: health) else { return nil }
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmm"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("APEX-OS-Backup-\(df.string(from: Date())).apexbackup.json")
        do {
            try data.write(to: url, options: .atomic)
            // Also write to iCloud Key-Value store if active on signed builds
            if data.count < 900_000 {
                NSUbiquitousKeyValueStore.default.set(data, forKey: cloudKey)
                NSUbiquitousKeyValueStore.default.synchronize()
            }
            lastBackupStatus = "Exported \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)) snapshot."
            return url
        } catch {
            lastBackupStatus = "Backup export failed: \(error.localizedDescription)"
            return nil
        }
    }

    public func syncBackupToMac(health: HealthKitManager) async {
        guard let data = encodeSnapshot(health: health) else {
            lastBackupStatus = "Could not encode backup snapshot."
            return
        }
        isSyncingBackup = true
        let ok = await health.pushBackupSnapshotToMac(data)
        isSyncingBackup = false
        lastBackupStatus = ok
            ? "Synced snapshot (\(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))) to Mac Companion."
            : "Mac Companion unreachable — connect on Summary tab or share .apexbackup file."
    }

    public func restoreFromCloudIfNewer(health: HealthKitManager) -> Bool {
        NSUbiquitousKeyValueStore.default.synchronize()
        guard let data = NSUbiquitousKeyValueStore.default.data(forKey: cloudKey) else {
            lastBackupStatus = "No iCloud Key-Value snapshot found on this Apple ID."
            return false
        }
        return importSnapshot(from: data, health: health)
    }

    @discardableResult
    public func importSnapshot(from data: Data, health: HealthKitManager) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let payload = try? decoder.decode(ApexBackupPayload.self, from: data) else {
            lastBackupStatus = "Invalid .apexbackup JSON file."
            return false
        }

        if let unit = ApexUnitSystem(rawValue: payload.unitSystem) {
            ApexUnitPreferences.current = unit
        }
        health.chronologicalAge = payload.chronologicalAge
        health.isAgeManuallySet = true
        health.baselineSleepGoalHours = payload.sleepGoalHours
        if let pheno = payload.clinicalPhenoAge {
            health.clinicalPhenoAgeValue = pheno
        }
        if let lab = payload.labPanel {
            LabPanelStore.save(lab)
        }
        if let tagBytes = try? JSONEncoder().encode(payload.dailyTagsByDate) {
            UserDefaults.standard.set(tagBytes, forKey: "apex_daily_journal_tags_v1")
        }
        if let expBytes = try? JSONEncoder().encode(payload.experimentLogs) {
            UserDefaults.standard.set(expBytes, forKey: "apex_experiment_logs_v1")
        }
        UserDefaults.standard.set(payload.activeProtocolId, forKey: "apex_active_experiment_id")

        if let prBytes = try? JSONEncoder().encode(payload.bestRecords) {
            UserDefaults.standard.set(prBytes, forKey: "apex_strength_prs_v1")
        }
        if let histBytes = try? JSONEncoder().encode(payload.completedWorkouts) {
            UserDefaults.standard.set(histBytes, forKey: "apex_strength_history_v1")
        }
        if let mealsBytes = try? JSONEncoder().encode(payload.meals) {
            UserDefaults.standard.set(mealsBytes, forKey: "apex_ios_logged_meals_v1")
        }
        if let recipesBytes = try? JSONEncoder().encode(payload.recipes) {
            UserDefaults.standard.set(recipesBytes, forKey: "apex_ios_custom_recipes_v1")
        }

        StrengthBuilderStore.shared.reloadFromDisk()
        NutritionLogStore.shared.reloadFromDisk()
        ExperimentLabStore.shared.reloadFromDisk()

        lastBackupStatus = "Restored backup from \(payload.deviceName) (\(payload.exportedAt.formatted(date: .abbreviated, time: .shortened)))."
        return true
    }
}

// MARK: - Physician Clinical PDF Dossier Generator (PDFKit / UIGraphicsPDFRenderer)
public enum ClinicalPDFGenerator {
    @MainActor
    public static func generatePDF(health: HealthKitManager) -> (data: Data, url: URL)? {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let margin: CGFloat = 42
        let contentWidth = pageRect.width - margin * 2

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: UIGraphicsPDFRendererFormat())
        let data = renderer.pdfData { ctx in
            var y: CGFloat = 0

            func startPage() {
                ctx.beginPage()
                y = margin
            }

            func ensureSpace(_ needed: CGFloat) {
                if y + needed > pageRect.height - margin {
                    startPage()
                }
            }

            func drawText(_ text: String, font: UIFont, color: UIColor, spacingAfter: CGFloat = 4) {
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let maxSize = CGSize(width: contentWidth, height: 1000)
                let rect = (text as NSString).boundingRect(with: maxSize, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
                ensureSpace(rect.height + spacingAfter)
                (text as NSString).draw(in: CGRect(x: margin, y: y, width: contentWidth, height: ceil(rect.height)), withAttributes: attrs)
                y += ceil(rect.height) + spacingAfter
            }

            func drawSectionHeader(_ title: String) {
                ensureSpace(34)
                y += 10
                let linePath = UIBezierPath()
                linePath.move(to: CGPoint(x: margin, y: y))
                linePath.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
                UIColor(white: 0.82, alpha: 1.0).setStroke()
                linePath.lineWidth = 0.75
                linePath.stroke()
                y += 8
                drawText(title.uppercased(), font: .systemFont(ofSize: 10, weight: .bold), color: UIColor(red: 0.08, green: 0.36, blue: 0.78, alpha: 1.0), spacingAfter: 6)
            }

            func drawRow(label: String, value: String) {
                ensureSpace(20)
                let labelAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10.5, weight: .medium), .foregroundColor: UIColor.darkGray]
                let valAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold), .foregroundColor: UIColor.black]
                (label as NSString).draw(in: CGRect(x: margin, y: y, width: contentWidth * 0.56, height: 16), withAttributes: labelAttrs)
                let valSize = (value as NSString).size(withAttributes: valAttrs)
                let valX = max(margin + contentWidth * 0.56, pageRect.width - margin - valSize.width)
                (value as NSString).draw(in: CGRect(x: valX, y: y, width: pageRect.width - margin - valX, height: 16), withAttributes: valAttrs)
                y += 18
            }

            startPage()

            // Header Block
            drawText("APEX OS · CLINICAL LONGEVITY & BIOMETRIC DOSSIER", font: .systemFont(ofSize: 15, weight: .bold), color: .black, spacingAfter: 3)
            let genTime = Date().formatted(date: .abbreviated, time: .shortened)
            let unitLabel = ApexUnitPreferences.current.displayLabel
            drawText("Generated \(genTime) · Chronological Age: \(Int(health.chronologicalAge)) yrs · Units: \(unitLabel) · Zero Synthetic Estimates", font: .systemFont(ofSize: 9.5, weight: .regular), color: .gray, spacingAfter: 10)

            // 1. Autonomic Recovery, Readiness & Sleep Architecture
            drawSectionHeader("1. Autonomic Recovery, Strain & Sleep (Apple Health Live)")
            drawRow(label: "Recovery Readiness Score", value: health.readinessScore.map { "\($0)%" } ?? "Not recorded")
            drawRow(label: "Daily Cardiovascular Strain (0-21)", value: health.todayStrainScore.map { String(format: "%.1f / 21", $0) } ?? "Not recorded")
            drawRow(label: "Adaptive Strain Target", value: health.targetStrainRange.map { String(format: "%.0f - %.0f", $0.lowerBound, $0.upperBound) } ?? "Awaiting readiness")
            drawRow(label: "Energy Bank Reserve", value: health.energyBankPercent.map { "\($0)%" } ?? "Not recorded")
            drawRow(label: "Resting Heart Rate", value: health.restingHeartRate.map { "\(Int($0.rounded())) bpm (\(health.rhrDeltaBpm.map { "\($0 >= 0 ? "+\($0)" : "\($0)") bpm vs 7d" } ?? "baseline building"))" } ?? "Not recorded")
            drawRow(label: "Heart Rate Variability (SDNN)", value: health.heartRateVariability.map { "\(Int($0.rounded())) ms (\(health.hrvDeltaPercent.map { "\($0 >= 0 ? "+\($0)" : "\($0)")% vs 7d" } ?? "baseline building"))" } ?? "Not recorded")
            drawRow(label: "VO2 Max (Cardiorespiratory)", value: health.vo2Max.map { String(format: "%.1f mL/kg*min", $0) } ?? "Not recorded")
            drawRow(label: "Last Night Sleep Total", value: health.sleepTotalHours.map { String(format: "%.1f hrs (Deep %.1fh / REM %.1fh)", $0, health.sleepDeepHours, health.sleepRemHours) } ?? "Not recorded")
            drawRow(label: "Tonight Sleep Needed / 7d Debt", value: health.sleepNeededHours.map { String(format: "%.1f hrs need / %.1fh debt", $0, health.sleepDebtHours ?? 0) } ?? "Not recorded")
            drawRow(label: "Activity Today", value: "\(Int(health.moveCalories)) kcal · \(Int(health.exerciseMinutes))m exercise · \(health.dailySteps) steps")

            // 2. Overnight 5-Vital Health Monitor
            drawSectionHeader("2. Overnight 5-Vital Health Monitor")
            let monitor = health.vitalRangeSummary
            if monitor.total == 0 {
                drawText("No overnight wearable vitals recorded yet. Sync Apple Watch / HealthKit to populate SpO2, Respiratory Rate, Wrist Temp, RHR, and HRV ranges.", font: .systemFont(ofSize: 10, weight: .regular), color: .darkGray, spacingAfter: 4)
            } else {
                drawRow(label: "Vitals Within Personal Baseline", value: "\(monitor.inRange) / \(monitor.total) in range")
                for item in monitor.items {
                    drawRow(label: "  \(item.name)", value: "\(item.value) (\(item.note))")
                }
            }

            // 3. Body Composition, PhenoAge & Bloodwork Panel
            drawSectionHeader("3. Epigenetic Aging, Body Composition & Bloodwork OCR")
            drawRow(label: "Body Weight", value: health.bodyWeightKg.map { ApexUnitPreferences.formatWeight(kg: $0) } ?? "Not recorded")
            drawRow(label: "Body Fat / Lean Mass", value: "\(health.bodyFatPercent.map { String(format: "%.1f%%", $0) } ?? "—") / \(health.leanBodyMassKg.map { ApexUnitPreferences.formatWeight(kg: $0) } ?? "—")")
            drawRow(label: "Fitness Biological Age", value: health.biologicalAge.map { String(format: "%.1f years", $0) } ?? "Not recorded")
            drawRow(label: "Bloodwork Levine PhenoAge", value: health.clinicalPhenoAge.map { String(format: "%.1f years", $0) } ?? "Not scanned")

            if let lab = LabPanelStore.load() {
                drawText("Latest Saved Lab Biomarkers (Scanned \(lab.scannedAt.formatted(date: .abbreviated, time: .omitted))):", font: .systemFont(ofSize: 9.5, weight: .semibold), color: .darkGray, spacingAfter: 4)
                drawRow(label: "  Albumin / Creatinine", value: String(format: "%.2f g/dL · %.2f mg/dL", lab.albuminGdL, lab.creatinineMgDL))
                drawRow(label: "  Fasting Glucose / hs-CRP", value: "\(ApexUnitPreferences.formatGlucose(mgDl: lab.glucoseMgDL)) · \(String(format: "%.2f mg/L", lab.crpMgL))")
                drawRow(label: "  Lymphocyte % / MCV / RDW", value: String(format: "%.1f%% · %.1f fL · %.1f%%", lab.lymphocytePct, lab.mcvFL, lab.rdwPct))
                drawRow(label: "  Alkaline Phosphatase / WBC", value: String(format: "%.0f U/L · %.1f K/uL", lab.alkPhosUL, lab.wbcCount))
            } else {
                drawText("No clinical blood panel saved yet. Scan a lab report in APEX Bloodwork OCR to include Biomarkers & Levine PhenoAge.", font: .systemFont(ofSize: 10, weight: .regular), color: .darkGray, spacingAfter: 4)
            }

            // 4. Metabolic Nutrition & CGM Summary
            let nutrition = NutritionLogStore.shared
            drawSectionHeader("4. Metabolic Fuel & Blood Glucose")
            drawRow(label: "Nutrition Quality Score Today", value: nutrition.nutritionQualityScore.map { "\($0) / 100 (\(nutrition.todaysMeals.count) meals)" } ?? "0 meals logged")
            drawRow(label: "Macro Intake Today", value: "\(Int(nutrition.todayCalories)) kcal · \(Int(nutrition.todayProtein))g P · \(Int(nutrition.todayCarbs))g C · \(Int(nutrition.todayFat))g F")
            drawRow(label: "Hydration & Caffeine", value: "\(Int(nutrition.waterMlToday)) mL water · \(Int(nutrition.caffeineMgToday)) mg caffeine")
            drawRow(label: "Latest Glucose Reading", value: health.glucoseSamples24h.last.map { ApexUnitPreferences.formatGlucose(mgDl: $0.value) } ?? "No glucose sample in 24h")

            // 5. Significant Causal Journal Impacts (>= 3 paired days only)
            let expStore = ExperimentLabStore.shared
            let impacts = JournalTag.presets.map { tag in
                (tag, expStore.journalCorrelation(forTagId: tag.id, health: health))
            }.filter { $0.1.hasEnoughData }

            drawSectionHeader("5. N-of-1 Journal Outcomes (Lag-1 Next-Morning Pairing)")
            if impacts.isEmpty {
                drawText("Accumulate >= 3 paired nights per lifestyle tag alongside HealthKit HRV/RHR/Sleep history to report statistically paired physiological deltas.", font: .systemFont(ofSize: 10, weight: .regular), color: .darkGray, spacingAfter: 4)
            } else {
                for (tag, summary) in impacts {
                    let hrvStr = summary.hrvDeltaPct.map { "HRV \($0 >= 0 ? "+" : "")\(Int($0.rounded()))%" } ?? "HRV —"
                    let rhrStr = summary.rhrDeltaBpm.map { String(format: "RHR %+.1f bpm", $0) } ?? "RHR —"
                    drawRow(label: "\(tag.title) (\(summary.pairedDaysCount) paired days)", value: "\(hrvStr) · \(rhrStr)")
                }
            }

            // 6. Neuromuscular Strength PRs
            let prs = StrengthBuilderStore.shared.bestRecords
            let allExercises = StrengthBuilderStore.shared.allExercises
            if !prs.isEmpty {
                drawSectionHeader("6. Neuromuscular Strength Records (Brzycki Est. 1RM)")
                let sortedPRs = prs.sorted { $0.value.best1RM > $1.value.best1RM }.prefix(8)
                for (exId, rec) in sortedPRs {
                    let exName = allExercises.first(where: { $0.id == exId })?.name ?? exId
                    drawRow(label: exName, value: "\(ApexUnitPreferences.formatWeight(kg: rec.best1RM)) (Last: \(ApexUnitPreferences.formatWeight(kg: rec.lastWeightKg)) x \(rec.lastReps))")
                }
            }

            y += 16
            ensureSpace(24)
            drawText("Note: Informational wellness dossier computed locally on-device from user-authorized Apple HealthKit samples, Vision OCR scans, and manual logs. Review abnormal values with a licensed physician.", font: .italicSystemFont(ofSize: 8.5), color: .gray, spacingAfter: 0)
        }

        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("APEX-Clinical-Dossier-\(df.string(from: Date())).pdf")
        try? data.write(to: url, options: .atomic)
        return (data, url)
    }
}

private struct PDFKitRepresentedView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = UIColor.systemGroupedBackground
        view.document = PDFDocument(data: data)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(data: data)
    }
}

public struct ClinicalPDFReportSheet: View {
    @ObservedObject private var health = HealthKitManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var generated: (data: Data, url: URL)? = nil

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let doc = generated {
                    PDFKitRepresentedView(data: doc.data)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    ProgressView("Rendering Physician PDF Dossier...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(ApexTheme.background)
                }
            }
            .navigationTitle("Clinical PDF Dossier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                if let doc = generated {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: doc.url) {
                            Label("Share PDF", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .onAppear {
                generated = ClinicalPDFGenerator.generatePDF(health: health)
            }
        }
    }
}

// MARK: - Portable Backup & Cross-Device Restore Sheet
public struct BackupContinuitySheet: View {
    @ObservedObject private var health = HealthKitManager.shared
    @ObservedObject private var backup = ApexBackupCoordinator.shared
    @Environment(\.dismiss) private var dismiss

    @State private var exportedURL: URL? = nil
    @State private var showFileImporter = false

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section("Export & Continuity") {
                    if let url = exportedURL {
                        ShareLink(item: url) {
                            Label("Share .apexbackup Snapshot File", systemImage: "square.and.arrow.up.fill")
                                .foregroundStyle(ApexTheme.accentVolt)
                        }
                    } else {
                        Button {
                            Haptics.tap(.medium)
                            exportedURL = backup.exportBackupFileURL(health: health)
                        } label: {
                            Label("Generate Portable .apexbackup File", systemImage: "doc.badge.plus")
                                .foregroundStyle(ApexTheme.standCyan)
                        }
                    }

                    Button {
                        Haptics.tap(.medium)
                        Task { await backup.syncBackupToMac(health: health) }
                    } label: {
                        HStack {
                            Label("Sync Encrypted Snapshot to Mac", systemImage: "laptopcomputer.and.iphone")
                            Spacer()
                            if backup.isSyncingBackup { ProgressView() }
                        }
                    }
                }

                Section("Restore & Cross-Device Import") {
                    Button {
                        Haptics.tap()
                        showFileImporter = true
                    } label: {
                        Label("Import .apexbackup JSON File", systemImage: "tray.and.arrow.down.fill")
                    }

                    Button {
                        Haptics.tap()
                        _ = backup.restoreFromCloudIfNewer(health: health)
                    } label: {
                        Label("Check iCloud Key-Value Snapshot", systemImage: "icloud.and.arrow.down")
                    }
                }

                if let status = backup.lastBackupStatus {
                    Section("Status") {
                        Text(status)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Backup & Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                guard case .success(let urls) = result,
                      let url = urls.first,
                      url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) {
                    if backup.importSnapshot(from: data, health: health) {
                        Haptics.success()
                    }
                }
            }
        }
    }
}
