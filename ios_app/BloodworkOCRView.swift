import SwiftUI
import Vision
import VisionKit
import PhotosUI
import PDFKit
import UniformTypeIdentifiers

// MARK: - Clinical PhenoAge + Longevity Biomarker Panel
public struct LabBiomarkerPanel: Codable {
    public var albuminGdL: Double = 4.5
    public var creatinineMgDL: Double = 0.90
    public var glucoseMgDL: Double = 85.0
    public var crpMgL: Double = 0.6
    public var lymphocytePct: Double = 32.0
    public var mcvFL: Double = 89.0
    public var rdwPct: Double = 12.2
    public var alkPhosUL: Double = 68.0
    public var wbcCount: Double = 5.6
    public var scannedAt: Date = Date()

    // Extended Longevity & Endocrine Panel (optional; omitted when unmeasured)
    public var apoBMgDL: Double? = nil
    public var totalTestosteroneNgDL: Double? = nil
    public var freeTestosteronePgML: Double? = nil
    public var hba1cPct: Double? = nil
    public var vitaminDNgML: Double? = nil
    public var tshMIUL: Double? = nil

    public init() {}
}

public struct LabPanelSnapshot: Codable, Identifiable {
    public let id: UUID
    public let panel: LabBiomarkerPanel
    public let phenoAge: Double
    public let recordedAt: Date

    public init(id: UUID = UUID(), panel: LabBiomarkerPanel, phenoAge: Double, recordedAt: Date = Date()) {
        self.id = id
        self.panel = panel
        self.phenoAge = phenoAge
        self.recordedAt = recordedAt
    }
}

// MARK: - Native Apple VisionKit Document Scanner + PDFKit + VNRecognizeTextRequest Bloodwork OCR
public struct BloodworkOCRView: View {
    @ObservedObject private var health = HealthKitManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var panel: LabBiomarkerPanel = LabPanelStore.load() ?? LabBiomarkerPanel()
    @State private var history: [LabPanelSnapshot] = LabPanelStore.loadHistory()
    @State private var hasSavedOrScannedLabData: Bool = LabPanelStore.load() != nil
    @State private var showDocScanner: Bool = false
    @State private var showPDFImporter: Bool = false
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var isProcessingOCR: Bool = false
    @State private var extractedCount: Int = 0
    @State private var statusMessage: String? = LabPanelStore.load() == nil ? "Scan a paper lab sheet, import a lab PDF, or verify numbers below (showing reference defaults)." : nil

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    // 1. LIVE COMPUTED CLINICAL PHENOAGE RESULT
                    phenoAgeResultCard

                    // 2. DOCUMENT CAMERA, PHOTO LIBRARY, OR PDF IMPORTER
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            if VNDocumentCameraViewController.isSupported {
                                Button {
                                    Haptics.tap(.medium)
                                    showDocScanner = true
                                } label: {
                                    Label("Scan Sheet", systemImage: "doc.viewfinder.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 13)
                                        .background(ApexTheme.accentVolt)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                            }

                            PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                                Label(isProcessingOCR ? "Reading..." : "Lab Photo", systemImage: "photo.on.rectangle")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(ApexTheme.elevatedSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(ApexTheme.subtleBorder, lineWidth: 0.5)
                                    )
                            }

                            Button {
                                Haptics.tap()
                                showPDFImporter = true
                            } label: {
                                Label("Lab PDF", systemImage: "doc.text.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(ApexTheme.elevatedSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(ApexTheme.subtleBorder, lineWidth: 0.5)
                                    )
                            }
                        }
                    }

                    if let msg = statusMessage {
                        HStack(spacing: 8) {
                            Image(systemName: extractedCount > 0 ? "checkmark.circle.fill" : "info.circle.fill")
                                .foregroundStyle(extractedCount > 0 ? ApexTheme.accentEmerald : ApexTheme.standCyan)
                            Text(msg)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .appleCard(padding: 12, cornerRadius: 14)
                    }

                    // 3. LEVINE PHENOAGE CORE PANEL
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Levine PhenoAge Panel")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                            if hasSavedOrScannedLabData {
                                Button("Reset", role: .destructive) {
                                    resetPanel()
                                }
                                .font(.system(size: 12, weight: .semibold))
                            }
                        }

                        VStack(spacing: 10) {
                            biomarkerRow(label: "Albumin", unit: "g/dL", value: $panel.albuminGdL)
                            biomarkerRow(label: "Creatinine", unit: "mg/dL", value: $panel.creatinineMgDL)
                            biomarkerRow(label: "Fasting Glucose", unit: "mg/dL", value: $panel.glucoseMgDL)
                            biomarkerRow(label: "hs-CRP", unit: "mg/L", value: $panel.crpMgL)
                            biomarkerRow(label: "Lymphocytes", unit: "%", value: $panel.lymphocytePct)
                            biomarkerRow(label: "MCV", unit: "fL", value: $panel.mcvFL)
                            biomarkerRow(label: "RDW", unit: "%", value: $panel.rdwPct)
                            biomarkerRow(label: "Alk Phos", unit: "U/L", value: $panel.alkPhosUL)
                            biomarkerRow(label: "WBC", unit: "10³/µL", value: $panel.wbcCount)
                        }
                    }

                    // 4. EXTENDED LONGEVITY & ENDOCRINE BIOMARKERS
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Longevity & Hormone Panel (Optional)")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                            Text("OCR-extracted or manual; included in Physician PDF & AI Coach")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 10) {
                            optionalBiomarkerRow(label: "ApoB", unit: "mg/dL", optimal: "<80", value: $panel.apoBMgDL)
                            optionalBiomarkerRow(label: "HbA1c", unit: "%", optimal: "<5.3", value: $panel.hba1cPct)
                            optionalBiomarkerRow(label: "Vitamin D (25-OH)", unit: "ng/mL", optimal: "40–70", value: $panel.vitaminDNgML)
                            optionalBiomarkerRow(label: "Total Testosterone", unit: "ng/dL", optimal: "500–950", value: $panel.totalTestosteroneNgDL)
                            optionalBiomarkerRow(label: "Free Testosterone", unit: "pg/mL", optimal: "12–25", value: $panel.freeTestosteronePgML)
                            optionalBiomarkerRow(label: "TSH", unit: "mIU/L", optimal: "0.5–2.5", value: $panel.tshMIUL)
                        }
                    }

                    Button {
                        Haptics.success()
                        panel.scannedAt = Date()
                        LabPanelStore.save(panel)
                        LabPanelStore.appendHistory(panel, phenoAge: computedPhenoAge)
                        history = LabPanelStore.loadHistory()
                        hasSavedOrScannedLabData = true
                        health.saveClinicalPhenoAge(computedPhenoAge)
                        statusMessage = String(format: "Saved PhenoAge %.1f yrs + panel snapshot to longitudinal history.", computedPhenoAge)
                    } label: {
                        Text("Save Clinical PhenoAge & Snapshot")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(ApexTheme.accentEmerald)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    if !history.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("LONGITUDINAL LAB SNAPSHOTS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                                .tracking(0.8)

                            ForEach(history) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(String(format: "PhenoAge %.1f yrs", item.phenoAge))
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                        Text(summaryBadges(for: item.panel))
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text(item.recordedAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                    Button {
                                        LabPanelStore.deleteSnapshot(id: item.id)
                                        history = LabPanelStore.loadHistory()
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                            .padding(.leading, 6)
                                    }
                                }
                                .appleCard(padding: 12, cornerRadius: 14)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(ApexTheme.background)
            .navigationTitle("Bloodwork OCR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task { await runOCROnPickedPhoto(item) }
            }
            .sheet(isPresented: $showDocScanner) {
                DocumentCameraScannerSheet { images in
                    Task { await processOCRImages(images) }
                }
            }
            .fileImporter(
                isPresented: $showPDFImporter,
                allowedContentTypes: [.pdf, .image],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    Task { await processLabFile(url: url) }
                }
            }
        }
    }

    private func resetPanel() {
        Haptics.tap()
        LabPanelStore.clear()
        health.clinicalPhenoAgeValue = 0
        health.clinicalPhenoAgeDateStr = ""
        panel = LabBiomarkerPanel()
        hasSavedOrScannedLabData = false
        extractedCount = 0
        statusMessage = "Cleared saved clinical panel. Reference defaults shown."
    }

    private func summaryBadges(for p: LabBiomarkerPanel) -> String {
        var bits: [String] = [
            "CRP \(String(format: "%.2f", p.crpMgL))",
            "Glu \(Int(p.glucoseMgDL.rounded()))"
        ]
        if let apoB = p.apoBMgDL { bits.append("ApoB \(Int(apoB.rounded()))") }
        if let a1c = p.hba1cPct { bits.append("A1c \(String(format: "%.1f%%", a1c))") }
        if let vitD = p.vitaminDNgML { bits.append("VitD \(Int(vitD.rounded()))") }
        if let tt = p.totalTestosteroneNgDL { bits.append("T \(Int(tt.rounded()))") }
        return bits.joined(separator: " · ")
    }

    private var phenoAgeResultCard: some View {
        let pheno = computedPhenoAge
        let delta = pheno - health.chronologicalAge

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("CLINICAL EPIGENETIC PHENOAGE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ApexTheme.accentEmerald)
                Spacer()
                Text("Chronological \(Int(health.chronologicalAge))y")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                if hasSavedOrScannedLabData || extractedCount > 0 {
                    Text(String(format: "%.1f yrs", pheno))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    Text(delta <= 0
                         ? String(format: "%.1f yrs younger", abs(delta))
                         : String(format: "+%.1f yrs older", delta))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(delta <= 0 ? ApexTheme.accentEmerald : ApexTheme.accentAmber)
                } else {
                    Text("Awaiting Lab Scan")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appleCard(padding: 18, cornerRadius: 22)
    }

    private func biomarkerRow(label: String, unit: String, value: Binding<Double>) -> some View {
        let trackedBinding = Binding<Double>(
            get: { value.wrappedValue },
            set: { newValue in
                value.wrappedValue = newValue
                hasSavedOrScannedLabData = true
            }
        )
        return HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
            Spacer()
            TextField("", value: trackedBinding, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ApexTheme.standCyan)
                .frame(width: 72)
            Text(unit)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
        }
        .appleCard(padding: 12, cornerRadius: 14)
    }

    private func optionalBiomarkerRow(label: String, unit: String, optimal: String, value: Binding<Double?>) -> some View {
        let strBinding = Binding<String>(
            get: {
                if let val = value.wrappedValue {
                    return String(format: val.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", val)
                }
                return ""
            },
            set: { raw in
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    value.wrappedValue = nil
                } else if let parsed = Double(trimmed) {
                    value.wrappedValue = parsed
                    hasSavedOrScannedLabData = true
                }
            }
        )
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                Text("Optimal \(optimal)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            TextField("—", text: strBinding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ApexTheme.accentVolt)
                .frame(width: 72)
            Text(unit)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
        }
        .appleCard(padding: 12, cornerRadius: 14)
    }

    // Exact Levine PhenoAge Equation (Levine et al. 2018)
    private var computedPhenoAge: Double {
        let albGL = panel.albuminGdL * 10.0 // g/L
        let creatUmol = panel.creatinineMgDL * 88.4 // umol/L
        let glucMmol = panel.glucoseMgDL * 0.0555 // mmol/L
        let lnCRP = log(max(0.01, panel.crpMgL / 10.0)) // ln(mg/dL)

        let xb = -19.9067
            - 0.0336 * albGL
            + 0.0095 * creatUmol
            + 0.1953 * glucMmol
            + 0.0954 * lnCRP
            - 0.0120 * panel.lymphocytePct
            + 0.0268 * panel.mcvFL
            + 0.3306 * panel.rdwPct
            + 0.00188 * panel.alkPhosUL
            + 0.0554 * panel.wbcCount
            + 0.0804 * health.chronologicalAge

        let gamma = 0.0076927
        let mort = 1.0 - exp((-exp(xb) * (exp(120.0 * gamma) - 1.0)) / gamma)
        let clampedMort = min(0.9999, max(0.0001, mort))
        let phenoAge = 141.50225 + log(-0.00553 * log(1.0 - clampedMort)) / 0.090165
        return max(16.0, min(99.0, (phenoAge * 10).rounded() / 10))
    }

    private func runOCROnPickedPhoto(_ item: PhotosPickerItem) async {
        isProcessingOCR = true
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            await processOCRImages([image])
        } else {
            isProcessingOCR = false
            statusMessage = "Unable to open selected image."
        }
        selectedPhoto = nil
    }

    private func processLabFile(url: URL) async {
        isProcessingOCR = true
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }

        if url.pathExtension.lowercased() == "pdf", let pdf = PDFDocument(url: url) {
            var extractedText = ""
            var pageImages: [UIImage] = []
            for idx in 0..<min(10, pdf.pageCount) {
                guard let page = pdf.page(at: idx) else { continue }
                if let str = page.string, !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    extractedText += str + "\n"
                } else {
                    let bounds = page.bounds(for: .mediaBox)
                    let scale: CGFloat = 2.0
                    let thumb = page.thumbnail(of: CGSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox)
                    pageImages.append(thumb)
                }
            }
            if !extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let hits = parseLabText(extractedText.lowercased())
                extractedCount = hits
                if hits > 0 { hasSavedOrScannedLabData = true }
                isProcessingOCR = false
                statusMessage = hits > 0
                    ? "Parsed \(hits) biomarkers directly from PDF lab report."
                    : "PDF text read, but no standard marker labels matched — verify values below."
                return
            } else if !pageImages.isEmpty {
                await processOCRImages(pageImages)
                return
            }
        } else if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
            await processOCRImages([img])
            return
        }

        isProcessingOCR = false
        statusMessage = "Unable to extract text from the selected lab file."
    }

    private func processOCRImages(_ images: [UIImage]) async {
        isProcessingOCR = true
        var recognizedLines: [String] = []

        for img in images {
            guard let cgImage = img.cgImage else { continue }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            if (try? handler.perform([request])) != nil,
               let observations = request.results {
                for obs in observations {
                    if let line = obs.topCandidates(1).first?.string {
                        recognizedLines.append(line)
                    }
                }
            }
        }

        let fullText = recognizedLines.joined(separator: "\n").lowercased()
        let hits = parseLabText(fullText)
        extractedCount = hits
        if hits > 0 { hasSavedOrScannedLabData = true }
        isProcessingOCR = false
        statusMessage = hits > 0
            ? "Parsed \(hits) biomarker values via Apple Vision OCR."
            : "No standard biomarker names matched cleanly — verify numbers manually below."
    }

    private func parseLabText(_ text: String) -> Int {
        var matched = 0

        func extract(_ patterns: [String], minVal: Double, maxVal: Double) -> Double? {
            for pat in patterns {
                if let regex = try? NSRegularExpression(pattern: pat, options: [.caseInsensitive]),
                   let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                   match.numberOfRanges >= 2,
                   let range = Range(match.range(at: 1), in: text),
                   let num = Double(text[range]),
                   num >= minVal && num <= maxVal {
                    matched += 1
                    return num
                }
            }
            return nil
        }

        if let v = extract(["albumin[^0-9]{0,24}([0-9]+\\.?[0-9]*)"], minVal: 2.0, maxVal: 6.5) { panel.albuminGdL = v }
        if let v = extract(["creatinine[^0-9]{0,24}([0-9]+\\.?[0-9]*)"], minVal: 0.3, maxVal: 3.5) { panel.creatinineMgDL = v }
        if let v = extract(["glucose[^0-9]{0,24}([0-9]+\\.?[0-9]*)"], minVal: 45, maxVal: 300) { panel.glucoseMgDL = v }
        if let v = extract(["(?:hs-?crp|c-?reactive protein|crp)[^0-9]{0,28}([0-9]+\\.?[0-9]*)"], minVal: 0.05, maxVal: 40) { panel.crpMgL = v }
        if let v = extract(["lymphocyte[s% ]{0,24}([0-9]+\\.?[0-9]*)"], minVal: 5, maxVal: 70) { panel.lymphocytePct = v }
        if let v = extract(["mcv[^0-9]{0,24}([0-9]+\\.?[0-9]*)"], minVal: 60, maxVal: 120) { panel.mcvFL = v }
        if let v = extract(["rdw[^0-9]{0,24}([0-9]+\\.?[0-9]*)"], minVal: 9, maxVal: 24) { panel.rdwPct = v }
        if let v = extract(["(?:alk\\s*phos|alkaline phosphatase)[^0-9]{0,24}([0-9]+\\.?[0-9]*)"], minVal: 20, maxVal: 300) { panel.alkPhosUL = v }
        if let v = extract(["(?:wbc|white blood cell)[^0-9]{0,24}([0-9]+\\.?[0-9]*)"], minVal: 1.5, maxVal: 25) { panel.wbcCount = v }

        // Extended Longevity & Endocrine Biomarkers
        if let v = extract(["(?:apo\\s*b|apolipoprotein\\s*b)[^0-9]{0,28}([0-9]+\\.?[0-9]*)"], minVal: 20, maxVal: 250) { panel.apoBMgDL = v }
        if let v = extract(["(?:hba1c|hemoglobin a1c|glycated hemoglobin|a1c)[^0-9]{0,28}([0-9]+\\.?[0-9]*)"], minVal: 3.5, maxVal: 15.0) { panel.hba1cPct = v }
        if let v = extract(["(?:vitamin d|25-?oh|25-hydroxy)[^0-9]{0,30}([0-9]+\\.?[0-9]*)"], minVal: 4, maxVal: 180) { panel.vitaminDNgML = v }
        if let v = extract(["(?:free testosterone|testosterone,? free)[^0-9]{0,28}([0-9]+\\.?[0-9]*)"], minVal: 1, maxVal: 60) { panel.freeTestosteronePgML = v }
        if let v = extract(["(?:total testosterone|testosterone,? total|testosterone)[^0-9]{0,28}([0-9]+\\.?[0-9]*)"], minVal: 50, maxVal: 2000) { panel.totalTestosteroneNgDL = v }
        if let v = extract(["(?:tsh|thyroid stimulating)[^0-9]{0,28}([0-9]+\\.?[0-9]*)"], minVal: 0.05, maxVal: 25.0) { panel.tshMIUL = v }

        return matched
    }
}

private struct DocumentCameraScannerSheet: UIViewControllerRepresentable {
    var onScanned: ([UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentCameraScannerSheet
        init(parent: DocumentCameraScannerSheet) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var pages: [UIImage] = []
            for idx in 0..<scan.pageCount {
                pages.append(scan.imageOfPage(at: idx))
            }
            parent.onScanned(pages)
            parent.dismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.dismiss()
        }
    }
}

public enum LabPanelStore {
    private static let key = "apex_ios_lab_panel_v1"
    private static let historyKey = "apex_ios_lab_history_v1"

    public static func load() -> LabBiomarkerPanel? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(LabBiomarkerPanel.self, from: data) else {
            return nil
        }
        return decoded
    }

    public static func save(_ panel: LabBiomarkerPanel) {
        if let encoded = try? JSONEncoder().encode(panel) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    public static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    public static func loadHistory() -> [LabPanelSnapshot] {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([LabPanelSnapshot].self, from: data) else {
            return []
        }
        return decoded
    }

    public static func saveHistory(_ items: [LabPanelSnapshot]) {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: historyKey)
        }
    }

    public static func appendHistory(_ panel: LabBiomarkerPanel, phenoAge: Double) {
        var list = loadHistory()
        list.insert(LabPanelSnapshot(panel: panel, phenoAge: phenoAge, recordedAt: Date()), at: 0)
        if list.count > 24 { list = Array(list.prefix(24)) }
        saveHistory(list)
    }

    public static func deleteSnapshot(id: UUID) {
        var list = loadHistory()
        list.removeAll { $0.id == id }
        saveHistory(list)
    }
}
