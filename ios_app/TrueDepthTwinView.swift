import SwiftUI
import RealityKit
import ARKit

// MARK: - Persistent TrueDepth 3D Vertex Snapshot for Inflammation / Bloat Comparison
public struct TrueDepthMeshSnapshot: Codable, Identifiable {
    public let id: UUID
    public let date: Date
    public let sampledVerticesXYZ: [Float] // Compact 180-vertex millimeter mesh for diff heatmap
    public let submentalWidthMm: Double
    public let cheekProjectionMm: Double
}

// MARK: - Interactive RealityKit 3D Digital Twin & Vertex Delta Sheet
public struct TrueDepthTwinSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var snapshots: [TrueDepthMeshSnapshot] = TrueDepthTwinStore.load()
    @State private var yawRadians: Float = 0.0
    @State private var pitchRadians: Float = 0.0
    @State private var baseYaw: Float = 0.0
    @State private var basePitch: Float = 0.0
    @State private var captureStatus: String = ARFaceTrackingConfiguration.isSupported
        ? "Align TrueDepth camera to record millimeter 3D mesh"
        : "TrueDepth LiDAR sensor requires a physical Face ID iPhone — no saved scan yet"

    @StateObject private var capturer = TrueDepthMeshCapturer()

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Interactive RealityKit 3D Viewport
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(ApexTheme.cardSurface)

                    RealityTwinViewport(
                        yaw: yawRadians,
                        pitch: pitchRadians,
                        latestMesh: snapshots.first,
                        baselineMesh: snapshots.count >= 2 ? snapshots.last : nil
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .gesture(
                        DragGesture()
                            .onChanged { val in
                                yawRadians = baseYaw + Float(val.translation.width) * 0.008
                                pitchRadians = max(-0.75, min(0.75, basePitch + Float(val.translation.height) * 0.005))
                            }
                            .onEnded { _ in
                                baseYaw = yawRadians
                                basePitch = pitchRadians
                            }
                    )

                    VStack {
                        HStack {
                            Text(snapshots.first != nil ? "3D MESH ACTIVE" : "NO SCAN · PREVIEW")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(snapshots.first != nil ? ApexTheme.standCyan : .secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                            Spacer()
                            Text("Drag to orbit 3D")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                }
                .frame(height: 300)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(ApexTheme.subtleBorder, lineWidth: 0.5)
                )

                // Inflammation / Morning Puffiness Delta Card
                if snapshots.count >= 2 {
                    let latest = snapshots[0]
                    let prev = snapshots[snapshots.count - 1]
                    let bloatDeltaMm = latest.cheekProjectionMm - prev.cheekProjectionMm
                    let jawDeltaMm = latest.submentalWidthMm - prev.submentalWidthMm

                    HStack(spacing: 12) {
                        AppleBiometricTile(
                            title: "Cheek Bloat Δ",
                            value: String(format: "%+.1f", bloatDeltaMm),
                            unit: "mm",
                            detail: bloatDeltaMm <= 0 ? "Leaner / Less Edema" : "Higher Fluid Retention",
                            tint: bloatDeltaMm <= 0 ? ApexTheme.accentEmerald : ApexTheme.accentAmber,
                            systemIcon: "drop.degreesign"
                        )
                        AppleBiometricTile(
                            title: "Jawline Span Δ",
                            value: String(format: "%+.1f", jawDeltaMm),
                            unit: "mm",
                            detail: "vs Baseline Mesh",
                            tint: ApexTheme.standCyan,
                            systemIcon: "cube.transparent"
                        )
                    }
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "cube.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(ApexTheme.standCyan)
                        Text(captureStatus)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .appleCard(padding: 14, cornerRadius: 16)
                }

                if ARFaceTrackingConfiguration.isSupported {
                    Button {
                        if let snap = capturer.captureSnapshot() {
                            snapshots.insert(snap, at: 0)
                            TrueDepthTwinStore.save(snapshots)
                            Haptics.success()
                            captureStatus = "Saved 3D millimeter twin (\(snapshots.count) total scans)"
                        } else {
                            capturer.startBriefCapture { snap in
                                if let snap {
                                    snapshots.insert(snap, at: 0)
                                    TrueDepthTwinStore.save(snapshots)
                                    Haptics.success()
                                    captureStatus = "Saved 3D millimeter twin"
                                }
                            }
                        }
                    } label: {
                        Label("Capture 3D Vertex Snapshot", systemImage: "camera.metering.center.weighted")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(ApexTheme.accentVolt)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                Spacer()
            }
            .padding(16)
            .background(ApexTheme.background)
            .navigationTitle("3D Digital Twin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onDisappear { capturer.stop() }
        }
    }
}

private struct RealityTwinViewport: UIViewRepresentable {
    let yaw: Float
    let pitch: Float
    let latestMesh: TrueDepthMeshSnapshot?
    let baselineMesh: TrueDepthMeshSnapshot?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        arView.environment.background = .color(.black)

        let anchor = AnchorEntity(world: [0, 0, -0.42])
        let meshContainer = Entity()
        anchor.addChild(meshContainer)

        let lightEntity = PointLight()
        lightEntity.light.intensity = 1500
        lightEntity.light.color = .white
        lightEntity.position = [0.2, 0.3, 0.25]
        anchor.addChild(lightEntity)

        arView.scene.addAnchor(anchor)
        context.coordinator.headRoot = anchor
        context.coordinator.meshContainer = meshContainer

        rebuildGeometry(in: context.coordinator)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        let qYaw = simd_quatf(angle: yaw, axis: [0, 1, 0])
        let qPitch = simd_quatf(angle: pitch, axis: [1, 0, 0])
        context.coordinator.headRoot?.orientation = qYaw * qPitch

        if context.coordinator.renderedMeshId != latestMesh?.id ||
           context.coordinator.renderedBaselineId != baselineMesh?.id {
            rebuildGeometry(in: context.coordinator)
        }
    }

    private func rebuildGeometry(in coordinator: Coordinator) {
        guard let container = coordinator.meshContainer else { return }
        container.children.removeAll()
        coordinator.renderedMeshId = latestMesh?.id
        coordinator.renderedBaselineId = baselineMesh?.id

        if let snap = latestMesh, snap.sampledVerticesXYZ.count >= 6 {
            let dotMesh = MeshResource.generateSphere(radius: 0.0024)
            var neutralMat = SimpleMaterial()
            neutralMat.color = .init(tint: UIColor(red: 0.0, green: 0.84, blue: 0.96, alpha: 0.95))
            neutralMat.metallic = 0.35
            neutralMat.roughness = 0.3

            var leanerMat = SimpleMaterial()
            leanerMat.color = .init(tint: UIColor(red: 0.18, green: 0.85, blue: 0.50, alpha: 0.96))
            leanerMat.roughness = 0.25

            var bloatMat = SimpleMaterial()
            bloatMat.color = .init(tint: UIColor(red: 1.0, green: 0.62, blue: 0.18, alpha: 0.96))
            bloatMat.roughness = 0.25

            let baseVerts = baselineMesh?.sampledVerticesXYZ
            let vertexCount = snap.sampledVerticesXYZ.count / 3
            for i in 0..<vertexCount {
                let bIdx = i * 3
                let vx = snap.sampledVerticesXYZ[bIdx] / 1000.0
                let vy = snap.sampledVerticesXYZ[bIdx + 1] / 1000.0
                let vz = snap.sampledVerticesXYZ[bIdx + 2] / 1000.0

                var chosenMat = neutralMat
                if let bv = baseVerts, bIdx + 2 < bv.count {
                    let deltaMm = snap.sampledVerticesXYZ[bIdx + 2] - bv[bIdx + 2]
                    if deltaMm > 0.8 {
                        chosenMat = bloatMat
                    } else if deltaMm < -0.5 {
                        chosenMat = leanerMat
                    }
                }

                let node = ModelEntity(mesh: dotMesh, materials: [chosenMat])
                node.position = [vx, vy, vz]
                container.addChild(node)
            }
        } else {
            // Wireframe preview placeholder when no 3D scan has been captured yet
            let mesh = MeshResource.generateSphere(radius: 0.108)
            var mat = SimpleMaterial()
            mat.color = .init(tint: UIColor(red: 0.0, green: 0.84, blue: 0.96, alpha: 0.28))
            mat.metallic = 0.45
            mat.roughness = 0.45
            let headEntity = ModelEntity(mesh: mesh, materials: [mat])
            headEntity.scale = [0.82, 1.12, 0.90]

            let ringMesh = MeshResource.generateBox(width: 0.16, height: 0.005, depth: 0.16, cornerRadius: 0.0025)
            var ringMat = SimpleMaterial()
            ringMat.color = .init(tint: UIColor(red: 0.0, green: 0.84, blue: 0.96, alpha: 0.45))
            let ringEntity = ModelEntity(mesh: ringMesh, materials: [ringMat])
            ringEntity.position = [0, -0.055, 0.015]

            container.addChild(headEntity)
            container.addChild(ringEntity)
        }
    }

    final class Coordinator {
        var headRoot: AnchorEntity?
        var meshContainer: Entity?
        var renderedMeshId: UUID?
        var renderedBaselineId: UUID?
    }
}

private final class TrueDepthMeshCapturer: NSObject, ObservableObject, ARSessionDelegate {
    private var session: ARSession?
    private var latestAnchor: ARFaceAnchor?
    private var pendingCallback: ((TrueDepthMeshSnapshot?) -> Void)?

    func startBriefCapture(completion: @escaping (TrueDepthMeshSnapshot?) -> Void) {
        guard ARFaceTrackingConfiguration.isSupported else {
            completion(nil)
            return
        }
        pendingCallback = completion
        let s = ARSession()
        s.delegate = self
        let cfg = ARFaceTrackingConfiguration()
        s.run(cfg)
        self.session = s
    }

    func stop() {
        session?.pause()
        session = nil
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        if let face = anchors.compactMap({ $0 as? ARFaceAnchor }).first {
            latestAnchor = face
            if let cb = pendingCallback {
                pendingCallback = nil
                let snap = snapshot(from: face)
                stop()
                DispatchQueue.main.async { cb(snap) }
            }
        }
    }

    func captureSnapshot() -> TrueDepthMeshSnapshot? {
        guard let anchor = latestAnchor else { return nil }
        return snapshot(from: anchor)
    }

    private func snapshot(from face: ARFaceAnchor) -> TrueDepthMeshSnapshot {
        let verts = face.geometry.vertices
        var flat: [Float] = []
        var jawMinX: Float = .greatestFiniteMagnitude
        var jawMaxX: Float = -.greatestFiniteMagnitude
        var faceMinX: Float = .greatestFiniteMagnitude
        var faceMaxX: Float = -.greatestFiniteMagnitude
        var cheekZAccum: Double = 0
        var cheekCount = 0

        for v in verts {
            if v.x < faceMinX { faceMinX = v.x }
            if v.x > faceMaxX { faceMaxX = v.x }
            // Submental / lower jawline band (-85mm .. -20mm vertical, front projection)
            if v.y >= -0.085 && v.y <= -0.020 && v.z > -0.015 {
                if v.x < jawMinX { jawMinX = v.x }
                if v.x > jawMaxX { jawMaxX = v.x }
            }
            // Zygomatic / buccal cheek band (-25mm .. +35mm vertical, lateral >= 25mm)
            if v.y >= -0.025 && v.y <= 0.035 && abs(v.x) >= 0.025 && v.z > 0.010 {
                cheekZAccum += Double(v.z * 1000.0)
                cheekCount += 1
            }
        }

        let strideStep = max(1, verts.count / 180)
        for i in stride(from: 0, to: verts.count, by: strideStep) {
            let v = verts[i]
            flat.append(v.x * 1000.0)
            flat.append(v.y * 1000.0)
            flat.append(v.z * 1000.0)
        }

        let submentalSpanMeters: Float = (jawMaxX > jawMinX) ? (jawMaxX - jawMinX) : max(0, faceMaxX - faceMinX)
        let cheekProjMm = cheekCount > 0 ? (cheekZAccum / Double(cheekCount)) : 32.0
        return TrueDepthMeshSnapshot(
            id: UUID(),
            date: Date(),
            sampledVerticesXYZ: flat,
            submentalWidthMm: Double(submentalSpanMeters) * 1000.0,
            cheekProjectionMm: cheekProjMm
        )
    }
}

private enum TrueDepthTwinStore {
    private static let key = "apex_truedepth_twin_snapshots_v1"

    static func load() -> [TrueDepthMeshSnapshot] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TrueDepthMeshSnapshot].self, from: data) else {
            return []
        }
        return decoded
    }

    static func save(_ items: [TrueDepthMeshSnapshot]) {
        if let data = try? JSONEncoder().encode(Array(items.prefix(15))) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
