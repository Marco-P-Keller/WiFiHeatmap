import SwiftUI

struct SignalGauge: View {
    let q: Double
    var connected = true

    var body: some View {
        let value = connected ? q : 0
        ZStack {
            Circle().trim(from: 0, to: 0.75)
                .stroke(.white.opacity(0.08), style: StrokeStyle(lineWidth: 22, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle().trim(from: 0, to: 0.75 * max(value, 0.015))
                .stroke(Signal.color(value), style: StrokeStyle(lineWidth: 22, lineCap: .round))
                .rotationEffect(.degrees(135))
                .shadow(color: Signal.color(value, opacity: 0.55), radius: 16)
                .animation(.smooth(duration: 0.6), value: value)
            VStack(spacing: 4) {
                if connected {
                    Text("\(Signal.dBm(value))")
                        .font(.system(size: 66, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .animation(.smooth, value: Signal.dBm(value))
                    Text("dBm (approx.)").font(.caption).foregroundStyle(Theme.secondary)
                    Text(Signal.label(value))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Signal.color(value))
                        .padding(.horizontal, 14).padding(.vertical, 5)
                        .background(Signal.color(value, opacity: 0.16), in: Capsule())
                        .padding(.top, 4)
                } else {
                    Image(systemName: "wifi.slash").font(.system(size: 52)).foregroundStyle(Theme.secondary)
                    Text("Not connected").font(.headline).foregroundStyle(Theme.secondary)
                }
            }
        }
        .frame(width: 260, height: 260)
    }
}

struct Sparkline: View {
    let values: [Double]
    var body: some View {
        GeometryReader { geo in
            let pts = values.enumerated().map { i, v in
                CGPoint(x: geo.size.width * CGFloat(i) / CGFloat(max(values.count - 1, 1)),
                        y: geo.size.height * (1 - CGFloat(min(max(v, 0), 1))))
            }
            ZStack {
                Path { p in
                    guard let f = pts.first else { return }
                    p.move(to: CGPoint(x: f.x, y: geo.size.height))
                    pts.forEach { p.addLine(to: $0) }
                    p.addLine(to: CGPoint(x: pts.last!.x, y: geo.size.height))
                }
                .fill(LinearGradient(colors: [Theme.accent.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom))
                Path { p in
                    guard let f = pts.first else { return }
                    p.move(to: f)
                    pts.dropFirst().forEach { p.addLine(to: $0) }
                }
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

struct DashboardView: View {
    let goScan: () -> Void
    @Environment(WiFiMonitor.self) private var monitor
    @Environment(PurchaseManager.self) private var purchases
    @Environment(SessionStore.self) private var store
    @State private var speed = SpeedTester()
    @State private var showLog = false
    @AppStorage("speedDay") private var speedDay = ""
    @AppStorage("speedCount") private var speedCount = 0

    private var connected: Bool { monitor.status == .connected || monitor.status == .demo }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        gaugeCard
                        speedCard
                        scanCTA
                        Button { showLog = true } label: {
                            Label("Log a dead spot here", systemImage: "mappin.and.ellipse")
                                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                                .glassBackground(cornerRadius: 20)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 18).padding(.bottom, 30)
                }
            }
            .navigationTitle("Signal")
            .sheet(isPresented: $showLog) { LogDeadSpotSheet() }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private var gaugeCard: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "wifi").foregroundStyle(Theme.accent)
                Text(monitor.ssid ?? "No Wi-Fi").font(.headline)
                Spacer()
                if connected { Circle().fill(Signal.color(monitor.quality)).frame(width: 10, height: 10) }
            }
            SignalGauge(q: monitor.quality, connected: connected)
            statusBanner
            if connected {
                Sparkline(values: monitor.history).frame(height: 54)
                Text("Walk around – the needle moves as you leave the router.")
                    .font(.footnote).foregroundStyle(Theme.secondary)
            }
        }
        .card()
    }

    @ViewBuilder private var statusBanner: some View {
        switch monitor.status {
        case .needsPermission:
            banner("Allow Location to read Wi-Fi strength", "Enable") { monitor.requestPermission() }
        case .denied:
            banner("Location is off – iOS needs it to read Wi-Fi", "Settings") {
                if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
            }
        case .notOnWiFi:
            banner("Join a Wi-Fi network to measure signal", nil, nil)
        default: EmptyView()
        }
    }

    private func banner(_ text: String, _ action: String?, _ run: (() -> Void)?) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(text).font(.subheadline)
            Spacer()
            if let action, let run { Button(action, action: run).buttonStyle(.borderedProminent).controlSize(.small) }
        }
        .padding(12)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var speedCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Speed Test", systemImage: "gauge.with.dots.needle.67percent").font(.headline)
                Spacer()
                if speed.phase == .download { Text("\(Fmt.mbps(speed.liveMbps)) Mbps").font(.subheadline.monospacedDigit()).foregroundStyle(Theme.accent) }
            }
            HStack(spacing: 10) {
                metric("Download", Fmt.mbps(speed.downMbps), "Mbps", Theme.accent)
                metric("Upload", Fmt.mbps(speed.upMbps), "Mbps", Theme.violet)
                metric("Ping", speed.pingMs.map { String(format: "%.0f", $0) } ?? "–", "ms", .green)
            }
            if speed.phase == .failed {
                Text("Test failed – check your connection and try again.").font(.footnote).foregroundStyle(.orange)
            }
            Button {
                startSpeedTest()
            } label: {
                HStack {
                    if speed.isRunning { ProgressView().tint(.black) }
                    Text(speed.isRunning ? phaseText : (speed.phase == .done ? "Test Again" : "Start Speed Test"))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(speed.isRunning || !connected)
            .opacity(connected ? 1 : 0.5)
        }
        .card()
    }

    private var phaseText: String {
        switch speed.phase {
        case .ping: return "Measuring latency…"
        case .download: return "Testing download…"
        case .upload: return "Testing upload…"
        default: return ""
        }
    }

    private func metric(_ title: String, _ value: String, _ unit: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(Theme.secondary)
            Text(value).font(.system(size: 26, weight: .bold, design: .rounded)).monospacedDigit()
                .contentTransition(.numericText())
            Text(unit).font(.caption2).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func startSpeedTest() {
        let today = Date.now.formatted(.iso8601.year().month().day())
        if speedDay != today { speedDay = today; speedCount = 0 }
        if !purchases.isPro && speedCount >= Config.freeSpeedTestsPerDay {
            _ = purchases.requirePro(.speedLimit)
            return
        }
        speedCount += 1
        Haptics.medium()
        Task { await speed.run() }
    }

    private var scanCTA: some View {
        Button(action: goScan) {
            ZStack(alignment: .bottomLeading) {
                ARDemoBackdrop()
                    .frame(maxWidth: .infinity).frame(height: 190).clipped()
                    .mask(LinearGradient(colors: [.black, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scan your home in AR").font(.title3.weight(.bold))
                    Text("Walk around and watch dead zones appear on your floor.")
                        .font(.footnote).foregroundStyle(.white.opacity(0.8))
                }
                .padding(16)
                .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.accent.opacity(0.4)))
        }
        .buttonStyle(.plain)
    }
}
