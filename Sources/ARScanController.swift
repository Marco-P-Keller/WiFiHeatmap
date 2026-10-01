import ARKit
import RealityKit
import SwiftUI
import Observation

@Observable
@MainActor
final class ARScanController: NSObject, ARSessionDelegate {
    static var isSupported: Bool { ARWorldTrackingConfiguration.isSupported }

    private(set) var isScanning = false
    private(set) var tileCount = 0
    private(set) var pins: [DeadZonePin] = []
    private(set) var trackingText = "Move your iPhone slowly"
    private(set) var trackingOK = false
    private(set) var distance: Float = 0
    private(set) var limitReached = false
    private(set) var samples: [SignalSample] = []

    var sampleLimit = Int.max
    var monitor: WiFiMonitor?

    private weak var arView: ARView?
    private let root = AnchorEntity(world: .zero)
    private var lastPos: SIMD3<Float>?
    private var floorY: Float?
    private var materials: [Int: UnlitMaterial] = [:]
    private static let tileMesh = MeshResource.generatePlane(width: 0.26, depth: 0.26, cornerRadius: 0.06)

    func attach(_ view: ARView) {
        arView = view
        view.session.delegate = self
        view.scene.addAnchor(root)
        run(reset: false)
    }

    func run(reset: Bool) {
        guard let arView else { return }
        let cfg = ARWorldTrackingConfiguration()
        cfg.planeDetection = [.horizontal]
        arView.session.run(cfg, options: reset ? [.resetTracking, .removeExistingAnchors] : [])
    }

    func pause() { arView?.session.pause() }

    func start() {
        reset()
        isScanning = true
        Haptics.medium()
    }

    func stop() { isScanning = false }

    func reset() {
        root.children.removeAll()
        samples = []; pins = []; tileCount = 0; distance = 0
        lastPos = nil; limitReached = false
        floorY = nil
    }

    /// Populates HUD counters for App Store screenshots taken in the Simulator (-demo only).
    func loadDemo() {
        isScanning = true; tileCount = 74; distance = 22.4; trackingOK = true; trackingText = "Tracking"
        pins = [DeadZonePin(x: 0, z: 0, q: 0.1), DeadZonePin(x: 1, z: 1, q: 0.1)]
    }

    func dropPin() {
        guard let arView, let monitor else { return }
        let cam = arView.cameraTransform.translation
        let y = (floorY ?? cam.y - 1.25)
        let pin = DeadZonePin(x: cam.x, z: cam.z, q: monitor.quality, note: "Dead zone \(pins.count + 1)")
        pins.append(pin)
        let mat = UnlitMaterial(color: .systemRed)
        let beam = ModelEntity(mesh: .generateBox(width: 0.03, height: 1.4, depth: 0.03, cornerRadius: 0.01), materials: [mat])
        beam.position = [cam.x, y + 0.7, cam.z]
        let orb = ModelEntity(mesh: .generateSphere(radius: 0.07), materials: [mat])
        orb.position = [cam.x, y + 1.45, cam.z]
        let ring = ModelEntity(mesh: .generateBox(width: 0.56, height: 0.01, depth: 0.56, cornerRadius: 0.28), materials: [mat])
        ring.position = [cam.x, y + 0.02, cam.z]
        [beam, orb, ring].forEach { root.addChild($0) }
        Haptics.warning()
    }

    func buildSession(name: String, downMbps: Double?) -> ScanSession {
        ScanSession(name: name, ssid: monitor?.ssid ?? "Wi-Fi", samples: samples, pins: pins, downMbps: downMbps, estimated: monitor?.usingEstimate)
    }

    // MARK: ARSessionDelegate

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let t = frame.camera.transform
        let state = frame.camera.trackingState
        MainActor.assumeIsolated { handle(t, state) }
    }

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) { planes(anchors) }
    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) { planes(anchors) }

    private nonisolated func planes(_ anchors: [ARAnchor]) {
        let ys = anchors.compactMap { ($0 as? ARPlaneAnchor).flatMap { $0.alignment == .horizontal ? $0.transform.columns.3.y : nil } }
        guard let lowest = ys.min() else { return }
        MainActor.assumeIsolated {
            // Only accept planes that are plausibly the floor (below the phone).
            if let cam = arView?.cameraTransform.translation.y, lowest < cam - 0.6 {
                floorY = min(floorY ?? lowest, lowest)
            }
        }
    }

    private func handle(_ t: simd_float4x4, _ state: ARCamera.TrackingState) {
        switch state {
        case .normal: trackingText = floorY == nil ? "Point at the floor to calibrate" : "Tracking"; trackingOK = true
        case .notAvailable: trackingText = "Tracking unavailable"; trackingOK = false
        case .limited(let r):
            trackingOK = false
            switch r {
            case .excessiveMotion: trackingText = "Slow down a little"
            case .insufficientFeatures: trackingText = "Aim at textured surfaces / better light"
            case .initializing: trackingText = "Initializing…"
            case .relocalizing: trackingText = "Relocalizing…"
            @unknown default: trackingText = "Limited tracking"
            }
        }
        guard isScanning, case .normal = state, let monitor, monitor.status == .connected || monitor.status == .demo else {
            if isScanning, monitor?.status == .notOnWiFi { trackingText = "Connect to Wi-Fi to scan" }
            return
        }
        let pos = SIMD3(t.columns.3.x, t.columns.3.y, t.columns.3.z)
        if let last = lastPos {
            let d = simd_distance(SIMD2(last.x, last.z), SIMD2(pos.x, pos.z))
            guard d >= 0.28 else { return }
            distance += d
        }
        if samples.count >= sampleLimit {
            limitReached = true
            isScanning = false
            Haptics.warning()
            return
        }
        lastPos = pos
        let q = monitor.quality
        let floor = floorY ?? (pos.y - 1.25)
        samples.append(SignalSample(x: pos.x, y: floor, z: pos.z, q: q))
        tileCount = samples.count
        placeTile(q: q, at: SIMD3(pos.x, floor + 0.012 + Float(tileCount % 12) * 0.0007, pos.z))
        if tileCount % 6 == 0 { Haptics.tap() }
    }

    private func material(for q: Double) -> UnlitMaterial {
        let key = Int((q * 24).rounded())
        if let m = materials[key] { return m }
        var m = UnlitMaterial(color: Signal.ui(Double(key) / 24))
        m.blending = .transparent(opacity: .init(floatLiteral: 0.78))
        materials[key] = m
        return m
    }

    private func placeTile(q: Double, at p: SIMD3<Float>) {
        let e = ModelEntity(mesh: Self.tileMesh, materials: [material(for: q)])
        e.position = p
        e.scale = SIMD3(repeating: 0.2)
        root.addChild(e)
        e.move(to: Transform(scale: .one, translation: p), relativeTo: root, duration: 0.3, timingFunction: .easeOut)
    }
}

struct ARHeatmapView: UIViewRepresentable {
    let controller: ARScanController

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        view.renderOptions.insert(.disableMotionBlur)
        view.renderOptions.insert(.disableDepthOfField)
        let coaching = ARCoachingOverlayView()
        coaching.session = view.session
        coaching.goal = .horizontalPlane
        coaching.activatesAutomatically = true
        coaching.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(coaching)
        controller.attach(view)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: ()) {
        uiView.session.pause()
    }
}
