import SwiftUI

struct RootView: View {
    enum AppTab: Hashable { case signal, scan, log, settings }

    @Environment(WiFiMonitor.self) private var monitor
    @Environment(PurchaseManager.self) private var purchases
    @AppStorage("didOnboard") private var didOnboard = false
    @State private var tab: AppTab = Self.initialTab
    @State private var demoResult: ScanSession?

    private static var args: [String] { ProcessInfo.processInfo.arguments }
    private static func arg(_ key: String) -> String? {
        guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    private static var initialTab: AppTab {
        switch arg("-tab") {
        case "scan": return .scan
        case "log": return .log
        case "settings": return .settings
        default: return .signal
        }
    }

    var body: some View {
        Group {
            if didOnboard || Self.arg("-screen") != nil && Self.arg("-screen") != "onboarding" {
                tabs
            } else {
                OnboardingView {
                    didOnboard = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        _ = purchases.requirePro(.onboarding)
                    }
                }
            }
        }
        .environment(\.paywallScope, "root")
        .paywallSheet()
        .task {
            monitor.start()
            switch Self.arg("-screen") {
            case "paywall": purchases.paywallScope = "root"; purchases.paywallReason = .onboarding
            case "result": demoResult = DemoData.session()
            default: break
            }
        }
        .fullScreenCover(item: $demoResult) { s in ScanResultView(session: s, isNew: false, isCover: true) }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            DashboardView(goScan: { tab = .scan })
                .tabItem { Label("Signal", systemImage: "wifi") }
                .tag(AppTab.signal)
            ARScanView()
                .tabItem { Label("AR Scan", systemImage: "arkit") }
                .tag(AppTab.scan)
            LogView()
                .tabItem { Label("Log", systemImage: "list.bullet.rectangle.portrait") }
                .tag(AppTab.log)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
    }
}
