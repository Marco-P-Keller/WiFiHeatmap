import Foundation
import CoreLocation
import NetworkExtension
import Observation

@Observable
@MainActor
final class WiFiMonitor: NSObject, CLLocationManagerDelegate {
    enum Status { case needsPermission, denied, notOnWiFi, connected, demo }

    private(set) var status: Status = .needsPermission
    private(set) var ssid: String?
    /// Smoothed 0…1 signal strength.
    private(set) var quality: Double = 0
    private(set) var history: [Double] = []

    private let location = CLLocationManager()
    private var timer: Timer?
    private var raw: Double = 0
    private var demoPhase = Double.random(in: 0...6)

    private var useDemoSignal: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return Config.isDemo
        #endif
    }

    override init() {
        super.init()
        location.delegate = self
        refreshAuth()
    }

    func requestPermission() {
        location.requestWhenInUseAuthorization()
    }

    func start() {
        guard timer == nil else { return }
        refreshAuth()
        let t = Timer(timeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.poll() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        Task { await poll() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.refreshAuth()
            await self.poll()
        }
    }

    private func refreshAuth() {
        if useDemoSignal { status = .demo; return }
        switch location.authorizationStatus {
        case .notDetermined: status = .needsPermission
        case .denied, .restricted: status = .denied
        default: if status == .needsPermission || status == .denied { status = .notOnWiFi }
        }
    }

    private func poll() async {
        if useDemoSignal {
            demoPhase += 0.12
            raw = 0.68 + 0.17 * sin(demoPhase) + 0.06 * sin(demoPhase * 2.7)
            ssid = "Home-5G"
            status = .demo
            push()
            return
        }
        guard status != .needsPermission, status != .denied else { return }
        if let net = await NEHotspotNetwork.fetchCurrent() {
            ssid = net.ssid
            raw = net.signalStrength
            status = .connected
            push()
        } else {
            ssid = nil
            status = .notOnWiFi
            raw = 0
            quality = 0
        }
    }

    private func push() {
        // Light smoothing keeps the gauge calm without hiding real dips.
        quality = history.isEmpty ? raw : quality * 0.35 + raw * 0.65
        history.append(raw)
        if history.count > 60 { history.removeFirst() }
    }
}
