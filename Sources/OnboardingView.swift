import SwiftUI

struct OnboardingView: View {
    let finish: () -> Void
    @Environment(WiFiMonitor.self) private var monitor
    @State private var page = 0

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    page1.tag(0)
                    page2.tag(1)
                    page3.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Capsule().fill(i == page ? Theme.accent : .white.opacity(0.2))
                            .frame(width: i == page ? 26 : 8, height: 8)
                    }
                }
                .animation(.spring(duration: 0.3), value: page)
                .padding(.bottom, 22)

                Button(page == 2 ? "Allow & Get Started" : "Continue") {
                    if page < 2 {
                        withAnimation { page += 1 }
                    } else {
                        monitor.requestPermission()
                        finish()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
    }

    private func slide<Art: View>(title: String, subtitle: String, @ViewBuilder art: () -> Art) -> some View {
        VStack(spacing: 22) {
            Spacer(minLength: 12)
            art().frame(maxHeight: 330)
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(Theme.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            Spacer(minLength: 12)
        }
    }

    private var page1: some View {
        slide(title: "See Your Wi-Fi.\nFinally.", subtitle: "Turn invisible signal into a live colour map of your home and find every dead zone in minutes.") {
            HeatmapCanvas(session: DemoData.session(), showPath: false)
                .padding(.horizontal, 26)
                .shadow(color: Theme.accent.opacity(0.25), radius: 30)
        }
    }

    private var page2: some View {
        slide(title: "Walk. Scan. Fix.", subtitle: "Hold your iPhone up and stroll through each room. Coloured tiles appear on your floor in AR – green is great, red is dead.") {
            ARDemoBackdrop(animated: true)
                .aspectRatio(0.62, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(.white.opacity(0.1)))
                .padding(.horizontal, 40)
        }
    }

    private var page3: some View {
        slide(title: "Two quick permissions", subtitle: "Both stay on your device. Nothing is recorded, uploaded or sold.") {
            VStack(spacing: 12) {
                permission("location.fill", "Location", "Required by iOS to read your Wi-Fi signal strength.")
                permission("camera.fill", "Camera", "Shows your room in AR so the heatmap lands on your floor.")
                permission("lock.shield.fill", "Private by design", "No account. No tracking. No ads.")
            }
            .padding(.horizontal, 24)
        }
    }

    private func permission(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2).foregroundStyle(Theme.accent)
                .frame(width: 46, height: 46)
                .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(Theme.secondary)
            }
            Spacer(minLength: 0)
        }
        .card(padding: 14)
    }
}

/// A stylised, animated preview of the AR floor heatmap. Shown during onboarding and on devices without ARKit.
struct ARDemoBackdrop: View {
    var animated = false
    @State private var start = Date()

    var body: some View {
        if animated {
            TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
                canvas(progress: min(ctx.date.timeIntervalSince(start) / 5.0, 1))
            }
        } else {
            canvas(progress: 1)
        }
    }

    private func quality(col: Int, row: Int) -> Double {
        let base = 1.0 - Double(col) * 0.105 - Double(row) * 0.012
        return max(0.03, min(1, base + sin(Double(row) * 1.3 + Double(col)) * 0.03))
    }

    private func canvas(progress: Double) -> some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: [Color(red: 0.10, green: 0.14, blue: 0.24), Color(red: 0.03, green: 0.05, blue: 0.10)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
            let horizon = h * 0.30
            let cx = w / 2
            let f = w * 0.72
            let camH = 1.45
            func proj(_ x: Double, _ z: Double) -> CGPoint {
                CGPoint(x: cx + f * x / (z + 0.6), y: horizon + f * camH / (z + 0.6))
            }
            // faint wall line
            ctx.stroke(Path { $0.move(to: CGPoint(x: 0, y: horizon)); $0.addLine(to: CGPoint(x: w, y: horizon)) },
                       with: .color(.white.opacity(0.08)), lineWidth: 1)
            let rows = 16, cols = 11
            let total = Double(rows * cols)
            var drawn = 0.0
            for row in stride(from: rows - 1, through: 0, by: -1) {
                for c in 0..<cols {
                    let col = c - cols / 2
                    drawn += 1
                    let order = Double(row * cols + c) / total
                    guard order <= progress else { continue }
                    let x0 = Double(col) * 0.5 - 0.23, x1 = x0 + 0.46
                    let z0 = Double(row) * 0.5 + 0.9, z1 = z0 + 0.46
                    var p = Path()
                    p.move(to: proj(x0, z0)); p.addLine(to: proj(x1, z0)); p.addLine(to: proj(x1, z1)); p.addLine(to: proj(x0, z1)); p.closeSubpath()
                    let q = quality(col: col + 5, row: row)
                    ctx.fill(p, with: .color(Signal.color(q, opacity: 0.9)))
                    ctx.stroke(p, with: .color(.white.opacity(0.18)), lineWidth: 0.8)
                }
            }
            // dead-zone pin
            let base = proj(2.0, 3.4), top = proj(2.0, 3.4)
            let beam = Path { $0.move(to: base); $0.addLine(to: CGPoint(x: top.x, y: top.y - h * 0.16)) }
            ctx.stroke(beam, with: .color(.red), lineWidth: 3)
            ctx.fill(Path(ellipseIn: CGRect(x: top.x - 7, y: top.y - h * 0.16 - 7, width: 14, height: 14)), with: .color(.red))
        }
    }
}
