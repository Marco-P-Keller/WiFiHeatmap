# WiFi Heatmap AR

See your Wi-Fi. Scan your home in AR, find every dead zone and fix it.

- **AR heatmap** – coloured tiles on your floor show signal strength (ARKit + RealityKit)
- **Floor-plan score** – interpolated top-down heatmap, 0–100 Wi-Fi score, share card
- **Dead-zone log** – pin trouble spots in AR or log them room by room
- **Speed test** – download / upload / ping
- **Fix-it advice** – rule-based tips for router and mesh placement
- StoreKit 2 subscriptions (yearly / weekly with free trial) + lifetime

SwiftUI, iOS 17+, no third-party dependencies. Project generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
xcodegen generate && open WiFiHeatmap.xcodeproj
```

Wi-Fi strength comes from `NEHotspotNetwork.fetchCurrent()` (needs the *Access Wi-Fi Information* entitlement and Location permission). iOS exposes a 0–1 value, not dBm; dBm in the UI is an estimate.

Simulator demo: launch with `-demo` (simulated signal and sample data). Support & privacy: https://marco-p-keller.github.io/WiFiHeatmap/
