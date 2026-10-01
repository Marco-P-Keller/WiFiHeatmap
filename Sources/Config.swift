import Foundation

enum Config {
    static let privacyURL = URL(string: "https://marco-p-keller.github.io/WiFiHeatmap/privacy.html")!
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let supportURL = URL(string: "https://marco-p-keller.github.io/WiFiHeatmap/")!

    /// Fill in after creating the app in App Store Connect (Apple ID of the app).
    static let appStoreID = ""
    static var shareURL: URL {
        appStoreID.isEmpty ? supportURL : URL(string: "https://apps.apple.com/app/id\(appStoreID)")!
    }

    static let freeARTileLimit = 40
    static let freeSavedScanLimit = 1
    static let freeDeadZoneLogLimit = 3
    static let freeSpeedTestsPerDay = 3

    enum Product {
        static let weekly = "com.connexa.WiFiHeatmap.pro.weekly"
        static let annual = "com.connexa.WiFiHeatmap.pro.annual"
        static let lifetime = "com.connexa.WiFiHeatmap.pro.lifetime"
        static let all = [annual, weekly, lifetime]
    }

    static var isDemo: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }
    static var forcePro: Bool { ProcessInfo.processInfo.arguments.contains("-forcePro") }
}
