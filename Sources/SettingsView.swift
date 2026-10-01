import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.requestReview) private var requestReview

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                List {
                    Section {
                        if purchases.isPro {
                            Label("WiFi Heatmap Pro is active", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                            Link("Manage subscription", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                        } else {
                            Button { _ = purchases.requirePro(.settings) } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "sparkles").font(.title2).foregroundStyle(.black)
                                        .frame(width: 48, height: 48)
                                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Get WiFi Heatmap Pro").font(.headline)
                                        Text("Unlimited AR scans, fixes & exports").font(.footnote).foregroundStyle(Theme.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(Theme.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        Button("Restore Purchases") { Task { await purchases.restore() } }
                    }
                    .listRowBackground(Color.white.opacity(0.06))

                    Section("Support") {
                        Button { requestReview() } label: { Label("Rate WiFi Heatmap", systemImage: "star.fill") }
                        ShareLink(item: Config.shareURL, message: Text("Find the Wi-Fi dead zones in your home with AR")) {
                            Label("Share with a friend", systemImage: "square.and.arrow.up")
                        }
                        Link(destination: Config.supportURL) { Label("Help & Feedback", systemImage: "questionmark.bubble") }
                    }
                    .listRowBackground(Color.white.opacity(0.06))

                    Section("Legal") {
                        Link("Privacy Policy", destination: Config.privacyURL)
                        Link("Terms of Use (EULA)", destination: Config.termsURL)
                    }
                    .listRowBackground(Color.white.opacity(0.06))

                    Section {
                        LabeledContent("Version", value: version)
                    } footer: {
                        Text("iOS reports Wi-Fi strength as a percentage, not raw dBm. dBm values shown here are estimates for easy comparison. Your scans stay on this device.")
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .toolbarBackground(.hidden, for: .navigationBar)
            .alert("Purchases", isPresented: Binding(get: { purchases.errorMessage != nil }, set: { if !$0 { purchases.errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(purchases.errorMessage ?? "") }
        }
    }
}
