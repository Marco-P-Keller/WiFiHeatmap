import Foundation
import StoreKit
import SwiftUI
import Observation

enum PaywallReason: String, Identifiable {
    case onboarding, arLimit, saveLimit, tips, export, deadZoneLimit, speedLimit, settings
    var id: String { rawValue }

    var headline: String {
        switch self {
        case .arLimit: return "Keep Scanning Your Whole Home"
        case .saveLimit: return "Save Every Room You Scan"
        case .tips: return "Fix Your Dead Zones"
        case .export: return "Share Your Heatmap, Clean"
        case .deadZoneLimit: return "Log Every Dead Spot"
        case .speedLimit: return "Unlimited Speed Tests"
        default: return "See Every Dead Zone"
        }
    }
}

private struct PaywallScopeKey: EnvironmentKey { static let defaultValue = "root" }
extension EnvironmentValues {
    var paywallScope: String {
        get { self[PaywallScopeKey.self] }
        set { self[PaywallScopeKey.self] = newValue }
    }
}

@Observable
@MainActor
final class PurchaseManager {
    private(set) var products: [Product] = []
    private(set) var isPro = false
    private(set) var isLoading = false
    var paywallReason: PaywallReason?
    var paywallScope = "root"
    var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        if Config.forcePro { isPro = true }
    }

    func start() async {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let t) = result { await t.finish() }
                await self?.refreshEntitlements()
            }
        }
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: Config.Product.all)
        } catch {
            errorMessage = "Couldn't load subscription options. Check your connection and try again."
        }
    }

    func product(_ id: String) -> Product? { products.first { $0.id == id } }

    func refreshEntitlements() async {
        var active = Config.forcePro
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, Config.Product.all.contains(t.productID), t.revocationDate == nil {
                active = true
            }
        }
        isPro = active
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let t) = verification {
                    await t.finish()
                    await refreshEntitlements()
                    if isPro { Haptics.success(); paywallReason = nil }
                    return isPro
                }
                errorMessage = "Purchase couldn't be verified."
            case .userCancelled, .pending: break
            @unknown default: break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        return false
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPro { errorMessage = "No previous purchases were found for this Apple ID." }
            else { paywallReason = nil }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Returns true when the action may proceed; otherwise presents the paywall in the given scope.
    func requirePro(_ reason: PaywallReason, scope: String = "root") -> Bool {
        if isPro { return true }
        paywallScope = scope
        paywallReason = reason
        return false
    }
}

struct PaywallSheetModifier: ViewModifier {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.paywallScope) private var scope

    func body(content: Content) -> some View {
        @Bindable var p = purchases
        let binding = Binding<PaywallReason?>(
            get: { purchases.paywallScope == scope ? purchases.paywallReason : nil },
            set: { purchases.paywallReason = $0 })
        content.sheet(item: binding) { reason in
            PaywallView(reason: reason)
                .environment(purchases)
        }
    }
}

extension View {
    func paywallSheet() -> some View { modifier(PaywallSheetModifier()) }
}
