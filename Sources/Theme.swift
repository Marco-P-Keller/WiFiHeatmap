import SwiftUI
import UIKit

struct RGB { var r: Double; var g: Double; var b: Double }

/// Single source of truth for the signal colour scale (used by SwiftUI, UIKit and RealityKit).
enum Signal {
    static let deadThreshold = 0.25

    private static let stops: [(Double, RGB)] = [
        (0.00, RGB(r: 0.96, g: 0.16, b: 0.27)),
        (0.25, RGB(r: 1.00, g: 0.47, b: 0.16)),
        (0.50, RGB(r: 1.00, g: 0.83, b: 0.16)),
        (0.75, RGB(r: 0.42, g: 0.90, b: 0.36)),
        (1.00, RGB(r: 0.12, g: 0.88, b: 0.86))
    ]

    static func rgb(_ q: Double) -> RGB {
        let v = min(max(q, 0), 1)
        for i in 1..<stops.count where v <= stops[i].0 {
            let (a, ca) = stops[i - 1], (b, cb) = stops[i]
            let t = (v - a) / (b - a)
            return RGB(r: ca.r + (cb.r - ca.r) * t, g: ca.g + (cb.g - ca.g) * t, b: ca.b + (cb.b - ca.b) * t)
        }
        return stops.last!.1
    }

    static func color(_ q: Double, opacity: Double = 1) -> Color {
        let c = rgb(q)
        return Color(red: c.r, green: c.g, blue: c.b).opacity(opacity)
    }

    static func ui(_ q: Double, alpha: CGFloat = 1) -> UIColor {
        let c = rgb(q)
        return UIColor(red: c.r, green: c.g, blue: c.b, alpha: alpha)
    }

    static func label(_ q: Double) -> String {
        switch q {
        case 0.75...: return "Excellent"
        case 0.55...: return "Good"
        case 0.35...: return "Fair"
        case deadThreshold...: return "Weak"
        default: return "Dead zone"
        }
    }

    /// iOS only exposes a 0…1 strength value; this maps it to an approximate dBm figure for display.
    static func dBm(_ q: Double) -> Int { Int((-90 + 60 * min(max(q, 0), 1)).rounded()) }

    static let legend = LinearGradient(
        stops: stops.map { .init(color: Color(red: $0.1.r, green: $0.1.g, blue: $0.1.b), location: $0.0) },
        startPoint: .leading, endPoint: .trailing)
}

enum Theme {
    static let accent = Color(red: 0.20, green: 0.85, blue: 0.95)
    static let bgTop = Color(red: 0.05, green: 0.08, blue: 0.19)
    static let bgBottom = Color(red: 0.02, green: 0.03, blue: 0.08)
    static let violet = Color(red: 0.45, green: 0.35, blue: 1.0)
    static let secondary = Color.white.opacity(0.62)
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.bgTop, Theme.bgBottom], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Theme.accent.opacity(0.22), .clear], center: .init(x: 0.9, y: 0.0), startRadius: 0, endRadius: 380)
            RadialGradient(colors: [Theme.violet.opacity(0.20), .clear], center: .init(x: 0.0, y: 0.75), startRadius: 0, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

struct CardStyle: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.09)))
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View { modifier(CardStyle(padding: padding)) }

    @ViewBuilder
    func glassBackground(cornerRadius: CGFloat = 22) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black.opacity(0.88))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                LinearGradient(colors: [tint, tint.opacity(0.78)], startPoint: .top, endPoint: .bottom),
                in: Capsule())
            .shadow(color: tint.opacity(0.45), radius: configuration.isPressed ? 4 : 14, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

enum Fmt {
    static func distance(_ meters: Double) -> String {
        let f = MeasurementFormatter()
        f.unitOptions = .naturalScale
        f.unitStyle = .short
        f.numberFormatter.maximumFractionDigits = meters < 10 ? 1 : 0
        return f.string(from: Measurement(value: meters, unit: UnitLength.meters))
    }

    static func mbps(_ v: Double?) -> String {
        guard let v else { return "–" }
        return v >= 100 ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}
