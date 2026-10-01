import AppKit
import CoreGraphics

let S = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(colorSpace: cs, components: [r, g, b, a])! }

// Background
let bg = CGGradient(colorsSpace: cs, colors: [c(0.07, 0.10, 0.24), c(0.02, 0.03, 0.09)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: CGFloat(S)), end: CGPoint(x: 0, y: 0), options: [])

// Heat glow (concentric heatmap)
let center = CGPoint(x: 512, y: 330)
let heat = CGGradient(colorsSpace: cs, colors: [
    c(0.12, 0.90, 0.88, 1.0), c(0.42, 0.90, 0.36, 0.95), c(1.0, 0.83, 0.16, 0.85),
    c(1.0, 0.47, 0.16, 0.65), c(0.96, 0.16, 0.27, 0.40), c(0.96, 0.16, 0.27, 0.0)
] as CFArray, locations: [0, 0.2, 0.42, 0.62, 0.82, 1])!
ctx.drawRadialGradient(heat, startCenter: center, startRadius: 0, endCenter: center, endRadius: 760, options: [])

// Vignette to calm the top
let top = CGGradient(colorsSpace: cs, colors: [c(0.02, 0.03, 0.09, 0.0), c(0.02, 0.03, 0.09, 0.55)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(top, start: CGPoint(x: 0, y: 300), end: CGPoint(x: 0, y: 1024), options: [])

// Wi-Fi symbol
ctx.setLineCap(.round)
ctx.setStrokeColor(c(1, 1, 1, 0.98))
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: c(0, 0, 0, 0.45))
let origin = CGPoint(x: 512, y: 300)
for (i, r) in [200.0, 360.0, 520.0].enumerated() {
    ctx.setLineWidth(i == 2 ? 70 : 70)
    ctx.addArc(center: origin, radius: CGFloat(r), startAngle: .pi * 0.25, endAngle: .pi * 0.75, clockwise: false)
    ctx.strokePath()
}
ctx.setFillColor(c(1, 1, 1, 1))
ctx.addEllipse(in: CGRect(x: origin.x - 62, y: origin.y - 62, width: 124, height: 124))
ctx.fillPath()

let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
let data = rep.representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
