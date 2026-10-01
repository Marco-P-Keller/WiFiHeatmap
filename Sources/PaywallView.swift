import SwiftUI
import StoreKit

struct PaywallView: View {
    let reason: PaywallReason

    @Environment(\.dismiss) private var dismiss
    @Environment(PurchaseManager.self) private var purchases
    @State private var selected = Config.Product.annual
    @State private var trialEligible: [String: Bool] = [:]
    @State private var showClose = false
    @State private var buying = false

    private struct Fallback { let price: String; let weekly: String? }
    private let fallbacks: [String: Fallback] = [
        Config.Product.annual: .init(price: "$29.99", weekly: "$0.58"),
        Config.Product.weekly: .init(price: "$4.99", weekly: nil),
        Config.Product.lifetime: .init(price: "$49.99", weekly: nil)
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AppBackground()
            ScrollView {
                VStack(spacing: 20) {
                    hero
                    VStack(spacing: 6) {
                        Text(reason.headline)
                            .font(.system(size: 31, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                        Text("Everything you need to find and fix weak Wi-Fi.")
                            .font(.subheadline).foregroundStyle(Theme.secondary).multilineTextAlignment(.center)
                    }
                    features
                }
                .padding(.horizontal, 20).padding(.top, 54).padding(.bottom, 20)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 10) {
                    plans
                    cta
                    legal
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 6)
                .background(.ultraThinMaterial)
            }
            if showClose {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.footnote.weight(.bold)).foregroundStyle(.white.opacity(0.75))
                        .frame(width: 34, height: 34).background(.white.opacity(0.12), in: Circle())
                }
                .padding(16)
                .transition(.opacity)
                .accessibilityLabel("Close")
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.0))
            withAnimation { showClose = true }
        }
        .task(id: purchases.products.count) {
            for p in purchases.products {
                if let sub = p.subscription { trialEligible[p.id] = await sub.isEligibleForIntroOffer }
            }
        }
        .interactiveDismissDisabled(buying)
    }

    // MARK: Sections

    private var hero: some View {
        HeatmapCanvas(session: DemoData.session(), showPath: false)
            .frame(height: 120)
            .mask(LinearGradient(colors: [.black, .black, .black.opacity(0.0)], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .bottomTrailing) {
                Label("Dead zone found", systemImage: "xmark.circle.fill")
                    .font(.caption.weight(.bold)).padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.red, in: Capsule()).padding(10)
            }
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 13) {
            feature("arkit", "Unlimited AR scanning", "Map every room, floor and garage")
            feature("wand.and.stars", "Personalised fix-it plan", "Exactly where to move or add a router")
            feature("square.stack.3d.up.fill", "Unlimited saved scans", "Track your score after every change")
            feature("square.and.arrow.up", "Clean shareable maps", "No watermark, plus unlimited speed tests")
        }
        .card()
    }

    private func feature(_ icon: String, _ title: String, _ sub: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon).font(.body.weight(.semibold)).foregroundStyle(Theme.accent)
                .frame(width: 34, height: 34)
                .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(sub).font(.caption).foregroundStyle(Theme.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var plans: some View {
        VStack(spacing: 8) {
            planRow(id: Config.Product.annual, title: "Yearly", badge: "BEST VALUE · SAVE 88%")
            planRow(id: Config.Product.weekly, title: "Weekly", badge: nil)
            planRow(id: Config.Product.lifetime, title: "Lifetime", badge: "PAY ONCE")
        }
    }

    private func planRow(id: String, title: String, badge: String?) -> some View {
        let p = purchases.product(id)
        let isSel = selected == id
        let price = p?.displayPrice ?? fallbacks[id]?.price ?? ""
        return Button { selected = id; Haptics.tap() } label: {
            HStack(spacing: 12) {
                Image(systemName: isSel ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(isSel ? Theme.accent : .white.opacity(0.3))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title).font(.headline)
                        if let badge {
                            Text(badge).font(.system(size: 10, weight: .heavy)).foregroundStyle(.black)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Theme.accent, in: Capsule())
                        }
                    }
                    Text(detail(id, price)).font(.caption).foregroundStyle(Theme.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(id == Config.Product.annual ? weeklyPrice(p) : price).font(.headline)
                    Text(id == Config.Product.annual ? "per week" : unit(id)).font(.caption2).foregroundStyle(Theme.secondary)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(isSel ? Theme.accent.opacity(0.12) : .white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(isSel ? Theme.accent : .white.opacity(0.08), lineWidth: isSel ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSel ? .isSelected : [])
    }

    private func weeklyPrice(_ p: Product?) -> String {
        guard let p else { return fallbacks[Config.Product.annual]?.weekly ?? "" }
        return (p.price / 52).formatted(p.priceFormatStyle)
    }

    private func unit(_ id: String) -> String {
        id == Config.Product.weekly ? "per week" : "one time"
    }

    private func trial(_ id: String) -> Bool {
        id != Config.Product.lifetime && (trialEligible[id] ?? true)
    }

    private func detail(_ id: String, _ price: String) -> String {
        switch id {
        case Config.Product.annual: return trial(id) ? "3-day free trial, then \(price)/year" : "\(price) billed yearly"
        case Config.Product.weekly: return trial(id) ? "3-day free trial, then \(price)/week" : "\(price) billed weekly"
        default: return "\(price) – one payment, yours forever"
        }
    }

    private var ctaTitle: String {
        if selected == Config.Product.lifetime { return "Unlock Forever" }
        return trial(selected) ? "Try 3 Days Free" : "Continue"
    }

    private var cta: some View {
        VStack(spacing: 10) {
            Button {
                guard let p = purchases.product(selected) else {
                    Task { await purchases.loadProducts() }
                    return
                }
                buying = true
                Task { await purchases.purchase(p); buying = false }
            } label: {
                HStack {
                    if buying || purchases.isLoading { ProgressView().tint(.black) }
                    Text(ctaTitle)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(buying)
            if selected != Config.Product.lifetime && trial(selected) {
                Label("No payment due now · Cancel anytime", systemImage: "checkmark.shield.fill")
                    .font(.footnote).foregroundStyle(Theme.secondary)
            }
        }
    }

    private var legal: some View {
        VStack(spacing: 10) {
            Text(legalText)
                .font(.system(size: 10)).foregroundStyle(Theme.secondary).multilineTextAlignment(.center)
            HStack(spacing: 18) {
                Button("Restore") { Task { await purchases.restore() } }
                Link("Terms", destination: Config.termsURL)
                Link("Privacy", destination: Config.privacyURL)
            }
            .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.7))
        }
    }

    private var legalText: String {
        if selected == Config.Product.lifetime {
            return "One-time purchase. Charged to your Apple ID at confirmation. No subscription."
        }
        return "Payment is charged to your Apple ID at confirmation of purchase (after any free trial ends). Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel any time in Settings › Apple ID › Subscriptions."
    }
}
