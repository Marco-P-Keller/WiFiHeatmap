import SwiftUI
import AVFoundation

struct ARScanView: View {
    @Environment(WiFiMonitor.self) private var monitor
    @Environment(PurchaseManager.self) private var purchases
    @State private var controller = ARScanController()
    @State private var result: ScanSession?
    @State private var toast: String?
    @State private var cameraDenied = AVCaptureDevice.authorizationStatus(for: .video) == .denied

    private var supported: Bool { ARScanController.isSupported && !Config.isDemo }

    var body: some View {
        ZStack {
            if cameraDenied {
                cameraDeniedView
            } else if Config.isDemo && ProcessInfo.processInfo.arguments.contains("arhud") {
                ARDemoBackdrop().ignoresSafeArea()
                hud
            } else if supported {
                ARHeatmapView(controller: controller).ignoresSafeArea()
                hud
            } else {
                unsupported
            }
        }
        .background(Color.black)
        .onAppear {
            monitor.start()
            controller.monitor = monitor
            if Config.isDemo && ProcessInfo.processInfo.arguments.contains("arhud") { controller.loadDemo() }
            controller.sampleLimit = purchases.isPro ? .max : Config.freeARTileLimit
            cameraDenied = AVCaptureDevice.authorizationStatus(for: .video) == .denied
        }
        .onChange(of: purchases.isPro) { _, pro in controller.sampleLimit = pro ? .max : Config.freeARTileLimit }
        .onChange(of: controller.limitReached) { _, hit in
            if hit { _ = purchases.requirePro(.arLimit, scope: "root") }
        }
        .fullScreenCover(item: $result, onDismiss: { controller.reset() }) { s in
            ScanResultView(session: s, isNew: true, isCover: true)
                .environment(monitor).environment(purchases)
        }
    }

    // MARK: HUD

    private var hud: some View {
        VStack(spacing: 10) {
            topBar
            if let toast {
                Text(toast).font(.subheadline.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 8)
                    .glassBackground(cornerRadius: 16).transition(.opacity.combined(with: .move(edge: .top)))
            }
            Spacer()
            if !controller.isScanning && controller.tileCount == 0 {
                instructions
            }
            if controller.limitReached {
                limitCard
            }
            controls
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "wifi").foregroundStyle(Signal.color(monitor.quality))
                VStack(alignment: .leading, spacing: 0) {
                    Text(monitor.ssid ?? "No Wi-Fi").font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text("\(Signal.label(monitor.quality)) · \(Signal.text(monitor.quality, estimated: monitor.usingEstimate))")
                        .font(.caption2).foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .glassBackground(cornerRadius: 18)
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(controller.trackingOK ? .green : .orange).frame(width: 8, height: 8)
                Text(controller.trackingText).font(.caption.weight(.medium)).lineLimit(1)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .glassBackground(cornerRadius: 18)
        }
    }

    private var instructions: some View {
        VStack(spacing: 6) {
            Text("Tap Start, then walk slowly").font(.headline)
            Text("Hold your iPhone at chest height and cover every room. Mark trouble spots with the red pin.")
                .font(.footnote).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.8))
        }
        .padding(16).frame(maxWidth: .infinity).glassBackground(cornerRadius: 22)
    }

    private var limitCard: some View {
        VStack(spacing: 10) {
            Text("Free scan limit reached").font(.headline)
            Text("Finish to see this scan, or unlock Pro to keep mapping your whole home.")
                .font(.footnote).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.8))
            Button("Unlock Unlimited Scanning") { _ = purchases.requirePro(.arLimit) }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(16).glassBackground(cornerRadius: 22)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 18) {
                stat("\(controller.tileCount)", "tiles")
                stat(Fmt.distance(Double(controller.distance)), "walked")
                stat("\(controller.pins.count)", "dead zones")
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
            .glassBackground(cornerRadius: 20)

            HStack(spacing: 18) {
                Button { controller.dropPin(); flash("Dead zone marked") } label: {
                    Image(systemName: "mappin.and.ellipse").font(.title2.weight(.semibold))
                        .frame(width: 62, height: 62).glassBackground(cornerRadius: 31)
                }
                .disabled(!controller.isScanning)
                .opacity(controller.isScanning ? 1 : 0.45)
                .accessibilityLabel("Mark dead zone")

                Button(action: toggle) {
                    ZStack {
                        Circle().strokeBorder(.white, lineWidth: 4).frame(width: 84, height: 84)
                        RoundedRectangle(cornerRadius: controller.isScanning ? 10 : 34, style: .continuous)
                            .fill(controller.isScanning ? Color.red : Theme.accent)
                            .frame(width: controller.isScanning ? 34 : 66, height: controller.isScanning ? 34 : 66)
                    }
                    .animation(.spring(duration: 0.3), value: controller.isScanning)
                }
                .accessibilityLabel(controller.isScanning ? "Stop scan" : "Start scan")

                Button { finishIfPossible() } label: {
                    Image(systemName: "checkmark").font(.title2.weight(.bold))
                        .frame(width: 62, height: 62).glassBackground(cornerRadius: 31)
                }
                .disabled(controller.tileCount < 8)
                .opacity(controller.tileCount < 8 ? 0.45 : 1)
                .accessibilityLabel("Finish and view heatmap")
            }
        }
        .foregroundStyle(.white)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 0) {
            Text(value).font(.headline.monospacedDigit()).contentTransition(.numericText())
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    private func toggle() {
        if controller.isScanning { controller.stop(); if controller.tileCount >= 8 { finishIfPossible() } }
        else { controller.start() }
    }

    private func finishIfPossible() {
        controller.stop()
        guard controller.tileCount >= 8 else { flash("Walk a little further first"); return }
        result = controller.buildSession(name: defaultName, downMbps: nil)
    }

    private var defaultName: String {
        "Scan " + Date.now.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    private func flash(_ text: String) {
        withAnimation { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { withAnimation { if toast == text { toast = nil } } }
    }

    // MARK: Fallback screens

    private var unsupported: some View {
        ZStack {
            ARDemoBackdrop(animated: true).ignoresSafeArea()
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                Spacer()
                Text("AR scanning")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("Walk through your home with your iPhone and coloured tiles map every dead zone onto your floor.")
                    .multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.85))
                Button("Preview with a sample home") {
                    result = DemoData.session(name: "Sample Home")
                }
                .buttonStyle(PrimaryButtonStyle())
                Text("Live AR scanning needs an iPhone with ARKit.")
                    .font(.footnote).foregroundStyle(.white.opacity(0.6))
            }
            .padding(24)
            .foregroundStyle(.white)
        }
    }

    private var cameraDeniedView: some View {
        ZStack {
            AppBackground()
            ContentUnavailableView {
                Label("Camera access needed", systemImage: "camera.fill")
            } description: {
                Text("AR scanning shows your room through the camera to paint the heatmap on your floor. Nothing is recorded.")
            } actions: {
                Button("Open Settings") {
                    if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
