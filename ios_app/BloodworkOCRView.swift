import SwiftUI
import Vision
import VisionKit
import PhotosUI

// MARK: - Clinical PhenoAge Biomarker Set
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
}

// MARK: - Native Apple VisionKit Document Scanner + VNRecognizeTextRequest Bloodwork OCR
public struct BloodworkOCRView: View {
    @ObservedObject private var health = HealthKitManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var panel: LabBiomarkerPanel = LabPanelStore.load() ?? LabBiomarkerPanel()
    @State private var showDocScanner: Bool = false
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var isProcessingOCR: Bool = false
    @State private var extractedCount: Int = 0
    @State private var statusMessage: String? = nil

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    // 1. LIVE COMPUTED CLINICAL PHENOAGE RESULT
                    phenoAgeResultCard

                    // 2. DOCUMENT CAMERA OR PHOTO LIBRARY OCR TRIGGERS
                    HStack(spacing: 12) {
                        if VNDocumentCameraViewController.isSupported {
                            Button {
                                Haptics.tap(.medium)
                                showDocScanner = true
                            } label: {
                                Label("Scan Lab Sheet", systemImage: "doc.viewfinder.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(ApexTheme.accentVolt)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }

                        PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                            Label(isProcessingOCR ? "Reading Text..." : "Pick Lab Photo", systemImage: "photo.on.rectangle")
                                .font(.system(size: 14, weight: .semibold))
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

                    // 3. EDITABLE BIOMARKER VERIFICATION GRID
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Levine PhenoAge Panel")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)

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

                    Button {
                        Haptics.success()
                        panel.scannedAt = Date()
                        LabPanelStore.save(panel)
                        health.saveClinicalPhenoAge(computedPhenoAge)
                        dismiss()
                    } label: {
                        Text("Save Clinical PhenoAge to Profile")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(ApexTheme.accentEmerald)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        }
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
                Text(String(format: "%.1f yrs", pheno))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                Text(delta <= 0
                     ? String(format: "%.1f yrs younger", abs(delta))
                     : String(format: "+%.1f yrs older", delta))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(delta <= 0 ? ApexTheme.accentEmerald : ApexTheme.accentAmber)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appleCard(padding: 18, cornerRadius: 22)
    }

    private func biomarkerRow(label: String, unit: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
            Spacer()
            TextField("", value: value, format: .number.precision(.fractionLength(0...2)))
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

        if let v = extract(["albumin[^0-9]{0,20}([0-9]+\\.?[0-9]*)"], minVal: 2.0, maxVal: 6.5) { panel.albuminGdL = v }
        if let v = extract(["creatinine[^0-9]{0,20}([0-9]+\\.?[0-9]*)"], minVal: 0.3, maxVal: 3.5) { panel.creatinineMgDL = v }
        if let v = extract(["glucose[^0-9]{0,20}([0-9]+\\.?[0-9]*)"], minVal: 45, maxVal: 300) { panel.glucoseMgDL = v }
        if let v = extract(["(?:hs-?crp|c-?reactive protein)[^0-9]{0,25}([0-9]+\\.?[0-9]*)"], minVal: 0.05, maxVal: 40) { panel.crpMgL = v }
        if let v = extract(["lymphocyte[s% ]{0,20}([0-9]+\\.?[0-9]*)"], minVal: 5, maxVal: 70) { panel.lymphocytePct = v }
        if let v = extract(["mcv[^0-9]{0,20}([0-9]+\\.?[0-9]*)"], minVal: 60, maxVal: 120) { panel.mcvFL = v }
        if let v = extract(["rdw[^0-9]{0,20}([0-9]+\\.?[0-9]*)"], minVal: 9, maxVal: 24) { panel.rdwPct = v }
        if let v = extract(["(?:alk\\s*phos|alkaline phosphatase)[^0-9]{0,20}([0-9]+\\.?[0-9]*)"], minVal: 20, maxVal: 300) { panel.alkPhosUL = v }
        if let v = extract(["(?:wbc|white blood cell)[^0-9]{0,20}([0-9]+\\.?[0-9]*)"], minVal: 1.5, maxVal: 25) { panel.wbcCount = v }

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

private enum LabPanelStore {
    private static let key = "apex_ios_lab_panel_v1"

    static func load() -> LabBiomarkerPanel? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(LabBiomarkerPanel.self, from: data) else {
            return nil
        }
        return decoded
    }

    static func save(_ panel: LabBiomarkerPanel) {
        if let encoded = try? JSONEncoder().encode(panel) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
}
