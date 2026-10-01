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
    /// True when iOS reports no signal strength (always 0) and quality is estimated by probing the connection.
    private(set) var usingEstimate = false
    private(set) var rawStrength: Double = 0

    private let probe = QualityProbe()
    private var probeQ = 0.5
    private var zeroStreak = 0
    private var probeTask: Task<Void, Never>?

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
            status = .connected
            rawStrength = net.signalStrength
            if rawStrength > 0.001 {
                zeroStreak = 0
                if usingEstimate { usingEstimate = false; probeTask?.cancel(); probeTask = nil }
                raw = rawStrength
                push()
            } else {
                zeroStreak += 1
                if zeroStreak >= 3 {
                    usingEstimate = true
                    startProbing()
                    raw = probeQ
                    push()
                }
            }
        } else {
            ssid = nil
            status = .notOnWiFi
            raw = 0
            quality = 0
            zeroStreak = 0
            probeTask?.cancel(); probeTask = nil
            usingEstimate = false
        }
    }

    private func startProbing() {
        guard probeTask == nil else { return }
        probeTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let q = await self.probe.measure()
                await MainActor.run { self.probeQ = self.probeQ * 0.4 + q * 0.6 }
                try? await Task.sleep(for: .milliseconds(300))
            }
        }
    }

    private func push() {
        // Light smoothing keeps the gauge calm without hiding real dips.
        quality = history.isEmpty ? raw : quality * 0.35 + raw * 0.65
        history.append(raw)
        if history.count > 60 { history.removeFirst() }
    }
}

/// Fallback when iOS exposes no Wi-Fi strength: estimates link quality from latency and a small download.
final class QualityProbe: @unchecked Sendable {
    private let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 3
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: c)
    }()

    func measure() async -> Double {
        let base = "https://speed.cloudflare.com/__down?bytes="
        do {
            _ = try await session.data(from: URL(string: base + "0")!)          // warm connection
            let t0 = CFAbsoluteTimeGetCurrent()
            _ = try await session.data(from: URL(string: base + "0")!)
            let rttMs = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            let t1 = CFAbsoluteTimeGetCurrent()
            let (d, _) = try await session.data(from: URL(string: base + "200000")!)
            let mbps = Double(d.count) * 8 / max(CFAbsoluteTimeGetCurrent() - t1, 0.001) / 1_000_000
            return 0.5 * Self.rttScore(rttMs) + 0.5 * Self.throughputScore(mbps)
        } catch {
            return 0.02
        }
    }

    private static func rttScore(_ ms: Double) -> Double {
        switch ms { case ..<25: return 1; case ..<50: return 0.8; case ..<90: return 0.6; case ..<150: return 0.4; case ..<300: return 0.2; default: return 0.08 }
    }

    private static func throughputScore(_ mbps: Double) -> Double {
        switch mbps { case 30...: return 1; case 15...: return 0.8; case 6...: return 0.6; case 2.5...: return 0.4; case 1...: return 0.2; default: return 0.08 }
    }
}
