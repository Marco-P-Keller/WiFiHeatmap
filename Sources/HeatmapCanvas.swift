import SwiftUI

/// Renders an interpolated top-down Wi-Fi heatmap (inverse-distance weighting) from AR scan samples.
struct HeatmapCanvas: View {
    let session: ScanSession
    var showPath = true
    var showPins = true
    var cornerRadius: CGFloat = 20

    var body: some View {
        let b = session.bounds
        let pad: Float = 0.9
        let w = b.width + pad * 2, h = b.height + pad * 2
        Canvas { ctx, size in
            let scale = min(size.width / CGFloat(w), size.height / CGFloat(h))
            let ox = (size.width - CGFloat(w) * scale) / 2
            let oy = (size.height - CGFloat(h) * scale) / 2
            func pt(_ x: Float, _ z: Float) -> CGPoint {
                CGPoint(x: ox + CGFloat(x - b.minX + pad) * scale, y: oy + CGFloat(z - b.minZ + pad) * scale)
            }

            // grid background
            let step = max(scale * 1.0, 18)
            var grid = Path()
            var gx: CGFloat = ox.truncatingRemainder(dividingBy: step)
            while gx < size.width { grid.move(to: CGPoint(x: gx, y: 0)); grid.addLine(to: CGPoint(x: gx, y: size.height)); gx += step }
            var gy: CGFloat = oy.truncatingRemainder(dividingBy: step)
            while gy < size.height { grid.move(to: CGPoint(x: 0, y: gy)); grid.addLine(to: CGPoint(x: size.width, y: gy)); gy += step }
            ctx.stroke(grid, with: .color(.white.opacity(0.04)), lineWidth: 1)

            let cells = 54
            let cell = CGFloat(max(w, h)) / CGFloat(cells)
            let samples = session.samples
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: max(scale * 0.18, 3)))
                var gz = -pad
                while gz < b.height + pad {
                    var gxx = -pad
                    while gxx < b.width + pad {
                        let wx = b.minX + gxx + Float(cell) / 2, wz = b.minZ + gz + Float(cell) / 2
                        var num = 0.0, den = 0.0, nearest = Float.infinity
                        for s in samples {
                            let dx = s.x - wx, dz = s.z - wz
                            let d2 = dx * dx + dz * dz
                            nearest = min(nearest, d2)
                            if d2 < 4 {
                                let wgt = 1.0 / Double(d2 + 0.05)
                                num += wgt * s.q; den += wgt
                            }
                        }
                        if den > 0 && nearest < 0.5 {
                            let q = num / den
                            let alpha = min(1.0, Double(0.75 - nearest) + 0.35)
                            let p0 = pt(wx - Float(cell) / 2, wz - Float(cell) / 2)
                            let r = CGRect(x: p0.x, y: p0.y, width: CGFloat(cell) * scale + 0.6, height: CGFloat(cell) * scale + 0.6)
                            layer.fill(Path(r), with: .color(Signal.color(q, opacity: max(alpha, 0.45))))
                        }
                        gxx += Float(cell)
                    }
                    gz += Float(cell)
                }
            }

            if showPath, samples.count > 1 {
                var path = Path()
                path.move(to: pt(samples[0].x, samples[0].z))
                for s in samples.dropFirst() { path.addLine(to: pt(s.x, s.z)) }
                ctx.stroke(path, with: .color(.white.opacity(0.14)), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round, dash: [2, 4]))
            }
            if let first = samples.first {
                let p = pt(first.x, first.z)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)), with: .color(.white))
                ctx.stroke(Path(ellipseIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)), with: .color(.white.opacity(0.5)), lineWidth: 1.5)
            }
            if showPins {
                for pin in session.pins {
                    let p = pt(pin.x, pin.z)
                    let r = CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)
                    ctx.fill(Path(ellipseIn: r.insetBy(dx: -6, dy: -6)), with: .color(.red.opacity(0.25)))
                    ctx.fill(Path(ellipseIn: r), with: .color(.red))
                    ctx.stroke(Path(ellipseIn: r), with: .color(.white), lineWidth: 2)
                    let x = ctx.resolve(Text(Image(systemName: "xmark")).font(.system(size: 9, weight: .black)).foregroundStyle(.white))
                    ctx.draw(x, at: p)
                }
            }
        }
        .aspectRatio(CGFloat(w / h), contentMode: .fit)
        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(.white.opacity(0.08)))
    }
}

struct SignalLegend: View {
    var body: some View {
        VStack(spacing: 6) {
            Signal.legend.frame(height: 8).clipShape(Capsule())
            HStack {
                Text("Dead").foregroundStyle(Signal.color(0))
                Spacer()
                Text("Weak")
                Spacer()
                Text("Good")
                Spacer()
                Text("Excellent").foregroundStyle(Signal.color(1))
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.secondary)
        }
    }
}

struct MiniHeatmap: View {
    let session: ScanSession
    var body: some View {
        HeatmapCanvas(session: session, showPath: false, showPins: false, cornerRadius: 14)
            .frame(width: 84, height: 64)
    }
}
