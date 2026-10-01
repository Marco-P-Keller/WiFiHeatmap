import Foundation
import simd

struct SignalSample: Codable, Identifiable, Hashable {
    var id = UUID()
    var x: Float
    var y: Float
    var z: Float
    var q: Double
}

struct DeadZonePin: Codable, Identifiable, Hashable {
    var id = UUID()
    var x: Float
    var z: Float
    var q: Double
    var note: String = ""
}

struct ScanSession: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var ssid: String
    var date = Date()
    var samples: [SignalSample]
    var pins: [DeadZonePin]
    var downMbps: Double?

    var averageQ: Double { samples.isEmpty ? 0 : samples.map(\.q).reduce(0, +) / Double(samples.count) }
    var weakestQ: Double { samples.map(\.q).min() ?? 0 }
    var strongestQ: Double { samples.map(\.q).max() ?? 0 }
    var deadFraction: Double {
        samples.isEmpty ? 0 : Double(samples.filter { $0.q < Signal.deadThreshold }.count) / Double(samples.count)
    }

    /// 0–100 home Wi-Fi score.
    var score: Int {
        guard !samples.isEmpty else { return 0 }
        let s = 0.72 * averageQ + 0.28 * (1 - min(deadFraction * 2.2, 1))
        return Int((min(max(s, 0), 1) * 100).rounded())
    }

    var grade: String {
        switch score {
        case 85...: return "Outstanding"
        case 70...: return "Great"
        case 55...: return "Decent"
        case 40...: return "Patchy"
        default: return "Needs help"
        }
    }

    var coveredArea: Double { Double(samples.count) * 0.09 }

    struct Bounds { var minX: Float; var maxX: Float; var minZ: Float; var maxZ: Float
        var width: Float { max(maxX - minX, 0.5) }
        var height: Float { max(maxZ - minZ, 0.5) }
    }

    var bounds: Bounds {
        let xs = samples.map(\.x) + pins.map(\.x)
        let zs = samples.map(\.z) + pins.map(\.z)
        return Bounds(minX: xs.min() ?? 0, maxX: xs.max() ?? 1, minZ: zs.min() ?? 0, maxZ: zs.max() ?? 1)
    }
}

struct DeadZoneEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var room: String
    var note: String
    var q: Double
    var ssid: String
    var date = Date()
}

/// Generates a believable sample home so the app can be demoed in the Simulator and for App Store screenshots.
enum DemoData {
    static func session(name: String = "My Apartment", shifted: Bool = false) -> ScanSession {
        let shiftedFactor = shifted ? 0.5 : 1.0
        var samples: [SignalSample] = []
        var rng = SeededRNG(seed: shifted ? 7 : 42)
        let router = shifted ? SIMD2<Float>(2.2, 0.4) : SIMD2<Float>(-1.5, 0.5)
        var row = 0
        var z: Float = -3.0
        while z <= 3.6 {
            var xs = Array(stride(from: Float(-4.5), through: 7.5, by: 0.4))
            if row % 2 == 1 { xs.reverse() }
            for x in xs {
                let inside = (z < 3.0 && x < 5.2) || (z > -1.5 && z < 3.6 && x >= 5.2 && x < 7.6)
                if !inside && !(abs(x) < 8 && abs(z) < 3.7 && x < 6.0) { continue }
                let d = simd_distance(SIMD2(x, z), router)
                var q = 1.04 - Double(d) * 0.105
                if x > 2.4 { q -= 0.12 * shiftedFactor }
                if x > 5.2 { q -= 0.30 * shiftedFactor }
                if z > 1.9 && x < 0 { q -= 0.10 }
                if z < -1.9 { q -= 0.14 }
                q += Double.random(in: -0.05...0.05, using: &rng)
                samples.append(SignalSample(x: x, y: 0, z: z, q: min(max(q, 0.02), 1)))
            }
            z += 0.4
            row += 1
        }
        let pins = shifted ? [] : [DeadZonePin(x: 6.9, z: 1.2, q: 0.08, note: "Bedroom"), DeadZonePin(x: 5.9, z: -1.0, q: 0.14, note: "Hallway end")]
        return ScanSession(name: name, ssid: "Home-5G", date: Date().addingTimeInterval(-3600 * 5),
                           samples: samples, pins: pins, downMbps: shifted ? 318 : 212)
    }
}

struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
