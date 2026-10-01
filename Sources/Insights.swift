import Foundation
import simd

struct Tip: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
}

enum Insights {
    static func tips(for s: ScanSession) -> [Tip] {
        guard s.samples.count >= 8 else {
            return [Tip(icon: "figure.walk", title: "Scan a bit more", detail: "Walk through every room you use to get precise advice.")]
        }
        var tips: [Tip] = []
        let sorted = s.samples.sorted { $0.q > $1.q }
        let n = max(sorted.count / 10, 1)
        let strong = centroid(Array(sorted.prefix(n)))
        let weak = centroid(Array(sorted.suffix(n)))
        let all = centroid(s.samples)
        let gap = Double(simd_distance(strong, weak))

        if s.deadFraction > 0.06 {
            let half = Fmt.distance(gap / 2)
            tips.append(Tip(icon: "wifi.router.fill",
                            title: "Add a mesh node or extender",
                            detail: "Your weakest area is \(Fmt.distance(gap)) from your strongest spot. Place a mesh node about \(half) from the router, toward the dead zone – never inside it."))
        }
        let offCenter = Double(simd_distance(strong, all))
        if offCenter > 2.5 {
            tips.append(Tip(icon: "arrow.up.and.down.and.arrow.left.and.right",
                            title: "Move your router toward the middle",
                            detail: "Your signal peaks \(Fmt.distance(offCenter)) away from the center of the area you scanned. A central spot shares coverage more evenly."))
        }
        if let d = s.downMbps, d < 60 {
            tips.append(Tip(icon: "bolt.horizontal.fill",
                            title: "Prefer the 5 GHz band",
                            detail: "Speeds near the router look low (\(Fmt.mbps(d)) Mbps). Connect close devices to 5 GHz or 6 GHz and keep 2.4 GHz for far rooms."))
        }
        tips.append(Tip(icon: "arrow.up.to.line",
                        title: "Lift it off the floor",
                        detail: "Routers work best at shoulder height, in the open, away from metal, mirrors, aquariums and microwaves."))
        if s.deadFraction <= 0.06 {
            tips.insert(Tip(icon: "checkmark.seal.fill", title: "Your coverage is solid",
                            detail: "Less than 6% of the scanned area is weak. Re-scan after any big furniture or router change."), at: 0)
        }
        tips.append(Tip(icon: "arrow.triangle.2.circlepath", title: "Re-scan after every change",
                        detail: "Save a new scan and compare the score – small moves of 1–2 m often add 10+ points."))
        return tips
    }

    private static func centroid(_ samples: [SignalSample]) -> SIMD2<Float> {
        guard !samples.isEmpty else { return .zero }
        let sx = samples.map(\.x).reduce(0, +), sz = samples.map(\.z).reduce(0, +)
        return SIMD2(sx / Float(samples.count), sz / Float(samples.count))
    }
}
