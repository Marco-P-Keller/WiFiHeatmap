import SwiftUI

@main
struct WiFiHeatmapApp: App {
    @State private var monitor = WiFiMonitor()
    @State private var store = SessionStore()
    @State private var purchases = PurchaseManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(monitor)
                .environment(store)
                .environment(purchases)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .task { await purchases.start() }
        }
    }
}
