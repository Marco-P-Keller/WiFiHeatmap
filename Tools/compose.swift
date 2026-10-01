import AppKit

let W = 1320, H = 2868
let raw = CommandLine.arguments[1], out = CommandLine.arguments[2]
struct Slide { let file: String; let line1: String; let line2: String; let sub: String; let c1: NSColor; let c2: NSColor }
func col(_ r: CGFloat,_ g: CGFloat,_ b: CGFloat) -> NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: 1) }
let slides = [
  Slide(file: "scan", line1: "SEE EVERY", line2: "DEAD ZONE", sub: "Walk around. Wi-Fi paints itself on your floor in AR.", c1: col(0.07,0.22,0.42), c2: col(0.02,0.04,0.12)),
  Slide(file: "result", line1: "YOUR HOME'S", line2: "WI-FI SCORE", sub: "A colour map of every room – plus the weak spots to fix.", c1: col(0.30,0.12,0.40), c2: col(0.03,0.03,0.12)),
  Slide(file: "signal", line1: "LIVE SIGNAL.", line2: "REAL SPEED.", sub: "Signal meter and speed test in one tap.", c1: col(0.05,0.30,0.38), c2: col(0.02,0.04,0.10)),
  Slide(file: "log", line1: "PROVE THE", line2: "IMPROVEMENT", sub: "Re-scan after moving your router and watch your score climb.", c1: col(0.10,0.30,0.25), c2: col(0.02,0.05,0.10)),
  Slide(file: "spots", line1: "LOG DEAD SPOTS", line2: "ROOM BY ROOM", sub: "Keep a record for your router, mesh or provider.", c1: col(0.38,0.12,0.18), c2: col(0.04,0.03,0.10)),
]
func font(_ size: CGFloat, _ w: NSFont.Weight) -> NSFont {
  let base = NSFont.systemFont(ofSize: size, weight: w)
  if let d = base.fontDescriptor.withDesign(.rounded), let f = NSFont(descriptor: d, size: size) { return f }
  return base
}
func drawText(_ s: String, _ f: NSFont, _ color: NSColor, centerY: CGFloat, ctx: CGContext) {
  let para = NSMutableParagraphStyle(); para.alignment = .center
  let a = NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: color, .paragraphStyle: para])
  let size = a.size()
  a.draw(in: CGRect(x: 60, y: centerY - size.height / 2, width: CGFloat(W) - 120, height: size.height * 1.3))
}
for (i, s) in slides.enumerated() {
  guard let shot = NSImage(contentsOfFile: "\(raw)/\(s.file).png") else { print("missing", s.file); continue }
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 32)!
  NSGraphicsContext.saveGraphicsState()
  let gc = NSGraphicsContext(bitmapImageRep: rep)!
  NSGraphicsContext.current = gc
  let ctx = gc.cgContext
  let cs = CGColorSpaceCreateDeviceRGB()
  let g = CGGradient(colorsSpace: cs, colors: [s.c1.cgColor, s.c2.cgColor] as CFArray, locations: [0, 1])!
  ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: CGFloat(H)), end: CGPoint(x: 0, y: 0), options: [])
  let glow = CGGradient(colorsSpace: cs, colors: [NSColor(srgbRed: 0.2, green: 0.85, blue: 0.95, alpha: 0.35).cgColor, NSColor(srgbRed: 0.2, green: 0.85, blue: 0.95, alpha: 0).cgColor] as CFArray, locations: [0, 1])!
  ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 1000, y: 1500), startRadius: 0, endCenter: CGPoint(x: 1000, y: 1500), endRadius: 900, options: [])

  drawText(s.line1, font(122, .heavy), .white, centerY: CGFloat(H) - 250, ctx: ctx)
  drawText(s.line2, font(122, .heavy), NSColor(srgbRed: 0.35, green: 0.92, blue: 1, alpha: 1), centerY: CGFloat(H) - 385, ctx: ctx)
  drawText(s.sub, font(46, .medium), NSColor.white.withAlphaComponent(0.78), centerY: CGFloat(H) - 500, ctx: ctx)

  // device frame
  let scale: CGFloat = 0.80
  let pw = CGFloat(W) * scale, ph = CGFloat(H) * scale
  let px = (CGFloat(W) - pw) / 2, py = CGFloat(H) - 600 - ph
  let rect = CGRect(x: px, y: py, width: pw, height: ph)
  ctx.saveGState()
  ctx.setShadow(offset: CGSize(width: 0, height: -30), blur: 80, color: NSColor.black.withAlphaComponent(0.6).cgColor)
  let path = CGPath(roundedRect: rect.insetBy(dx: -14, dy: -14), cornerWidth: 110, cornerHeight: 110, transform: nil)
  ctx.setFillColor(NSColor(white: 0.04, alpha: 1).cgColor); ctx.addPath(path); ctx.fillPath()
  ctx.restoreGState()
  ctx.saveGState()
  ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 96, cornerHeight: 96, transform: nil)); ctx.clip()
  shot.draw(in: rect)
  ctx.restoreGState()
  ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.25).cgColor); ctx.setLineWidth(3)
  ctx.addPath(CGPath(roundedRect: rect.insetBy(dx: -14, dy: -14), cornerWidth: 110, cornerHeight: 110, transform: nil)); ctx.strokePath()
  NSGraphicsContext.restoreGraphicsState()
  let png = rep.representation(using: .png, properties: [:])!
  try! png.write(to: URL(fileURLWithPath: "\(out)/\(i + 1)_\(s.file).png"))
}
