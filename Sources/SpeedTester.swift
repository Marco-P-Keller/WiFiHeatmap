import Foundation
import Observation

@Observable
@MainActor
final class SpeedTester {
    enum Phase: Equatable { case idle, ping, download, upload, done, failed }

    private(set) var phase: Phase = .idle
    private(set) var pingMs: Double?
    private(set) var downMbps: Double?
    private(set) var upMbps: Double?
    private(set) var liveMbps: Double = 0

    var isRunning: Bool { phase == .ping || phase == .download || phase == .upload }

    private let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.timeoutIntervalForRequest = 15
        return URLSession(configuration: c)
    }()

    private let base = "https://speed.cloudflare.com"

    func run() async {
        guard !isRunning else { return }
        pingMs = nil; downMbps = nil; upMbps = nil; liveMbps = 0
        do {
            phase = .ping
            pingMs = try await measurePing()
            phase = .download
            downMbps = try await measureDownload()
            phase = .upload
            upMbps = try await measureUpload()
            liveMbps = 0
            phase = .done
        } catch {
            liveMbps = 0
            phase = (downMbps != nil) ? .done : .failed
        }
    }

    private func measurePing() async throws -> Double {
        var best = Double.infinity
        let url = URL(string: "\(base)/__down?bytes=0")!
        for _ in 0..<5 {
            let t0 = CFAbsoluteTimeGetCurrent()
            _ = try await session.data(from: url)
            best = min(best, (CFAbsoluteTimeGetCurrent() - t0) * 1000)
        }
        return best
    }

    private func measureDownload() async throws -> Double {
        let url = URL(string: "\(base)/__down?bytes=80000000")!
        let counter = ByteCounter(maxSeconds: 7) { [weak self] mbps in
            Task { @MainActor in self?.liveMbps = mbps }
        }
        let cfg = URLSessionConfiguration.ephemeral
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        let s = URLSession(configuration: cfg, delegate: counter, delegateQueue: nil)
        defer { s.invalidateAndCancel() }
        return try await withCheckedThrowingContinuation { cont in
            counter.onFinish = { result in cont.resume(with: result) }
            s.dataTask(with: url).resume()
        }
    }

    private func measureUpload() async throws -> Double {
        var req = URLRequest(url: URL(string: "\(base)/__up")!)
        req.httpMethod = "POST"
        let payload = Data(count: 6_000_000)
        let t0 = CFAbsoluteTimeGetCurrent()
        _ = try await session.upload(for: req, from: payload)
        let dt = max(CFAbsoluteTimeGetCurrent() - t0, 0.001)
        return Double(payload.count) * 8 / dt / 1_000_000
    }
}

final class ByteCounter: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    var onFinish: ((Result<Double, Error>) -> Void)?
    private let maxSeconds: Double
    private let live: (Double) -> Void
    private var start = 0.0
    private var lastTick = 0.0
    private var total = 0
    private var window = 0
    private var finished = false

    init(maxSeconds: Double, live: @escaping (Double) -> Void) {
        self.maxSeconds = maxSeconds
        self.live = live
    }

    private func finish(_ task: URLSessionTask?, error: Error? = nil) {
        guard !finished else { return }
        finished = true
        task?.cancel()
        let dt = max(CFAbsoluteTimeGetCurrent() - start, 0.001)
        if total == 0, let error { onFinish?(.failure(error)); return }
        onFinish?(.success(Double(total) * 8 / dt / 1_000_000))
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let now = CFAbsoluteTimeGetCurrent()
        if start == 0 { start = now; lastTick = now }
        total += data.count
        window += data.count
        if now - lastTick > 0.25 {
            live(Double(window) * 8 / (now - lastTick) / 1_000_000)
            lastTick = now; window = 0
        }
        if now - start > maxSeconds { finish(dataTask) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if start == 0 { start = CFAbsoluteTimeGetCurrent() }
        finish(nil, error: error)
    }
}
