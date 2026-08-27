import AppKit
import Foundation

let side: CGFloat = 1024
let size = NSSize(width: side, height: side)
let image = NSImage(size: size)

image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else {
    fatalError("Failed to get CGContext")
}

ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)
ctx.interpolationQuality = .high

ctx.clear(CGRect(x: 0, y: 0, width: side, height: side))

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

func hexColor(_ hex: UInt32, alpha: CGFloat = 1.0) -> CGColor {
    rgb(
        CGFloat((hex >> 16) & 0xFF) / 255.0,
        CGFloat((hex >> 8) & 0xFF) / 255.0,
        CGFloat(hex & 0xFF) / 255.0,
        alpha
    )
}

let colorSpace = CGColorSpaceCreateDeviceRGB()

// 1. Apple Standard Squircle (824x824)
let plateRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let cornerRadius: CGFloat = 185.0
let squirclePath = CGPath(roundedRect: plateRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

// 2. Dock Ambient Drop Shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 34, color: rgb(0, 0, 0, 0.32))
ctx.setFillColor(rgb(0, 0, 0, 1))
ctx.addPath(squirclePath)
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 14, color: rgb(0, 0, 0, 0.18))
ctx.setFillColor(rgb(0, 0, 0, 1))
ctx.addPath(squirclePath)
ctx.fillPath()
ctx.restoreGState()

// 3. Vibrant Luminous Azure Gradient (Fresh, radiant, not dark!)
ctx.saveGState()
ctx.addPath(squirclePath)
ctx.clip()

let bgColors = [
    hexColor(0x56A0FB), // Top: crystal sky azure
    hexColor(0x3278F3), // Mid: radiant electric blue
    hexColor(0x1B55DC)  // Bottom: rich ultramarine
] as CFArray
if let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 0.5, 1.0]) {
    ctx.drawLinearGradient(bgGrad, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
}
// Top light sheen
let glowColors = [rgb(1, 1, 1, 0.35), rgb(1, 1, 1, 0.0)] as CFArray
if let gGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
    ctx.drawRadialGradient(gGrad, startCenter: CGPoint(x: 512, y: 924), startRadius: 0, endCenter: CGPoint(x: 512, y: 924), endRadius: 560, options: [])
}

// -------------------------------------------------------------------------
// 4. Central Emblem: Symphonic Folio (Music Sun & Open Art Book)
// -------------------------------------------------------------------------

// --- A. VINYL RECORD (Music + Film) ---
let vc = CGPoint(x: 512, y: 540)
let vr: CGFloat = 215
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -16), blur: 28, color: rgb(0, 0, 0, 0.44))
ctx.addArc(center: vc, radius: vr, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.setFillColor(hexColor(0x101218))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addArc(center: vc, radius: vr, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.clip()
let discColors = [hexColor(0x282C38), hexColor(0x13151D), hexColor(0x0A0B10)] as CFArray
if let dGrad = CGGradient(colorsSpace: colorSpace, colors: discColors, locations: [0.0, 0.5, 1.0]) {
    ctx.drawLinearGradient(dGrad, start: CGPoint(x: 512 - vr, y: vc.y + vr), end: CGPoint(x: 512 + vr, y: vc.y - vr), options: [])
}
// Micro-grooves
for r in stride(from: CGFloat(72), to: vr - 6, by: 6.0) {
    ctx.setLineWidth(1.0)
    let alpha = (Int(r) % 12 == 0) ? 0.28 : 0.09
    ctx.setStrokeColor(rgb(1, 1, 1, CGFloat(alpha)))
    ctx.addArc(center: vc, radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()
}
// Iridescent Sheen
let sheenColors = [rgb(1, 1, 1, 0.0), rgb(0.8, 0.9, 1.0, 0.28), rgb(1, 0.85, 0.65, 0.24), rgb(1, 1, 1, 0.0)] as CFArray
if let sGrad = CGGradient(colorsSpace: colorSpace, colors: sheenColors, locations: [0.0, 0.47, 0.53, 1.0]) {
    for rot in [0.75, 2.38] {
        ctx.saveGState()
        ctx.translateBy(x: vc.x, y: vc.y)
        ctx.rotate(by: CGFloat(rot))
        ctx.drawLinearGradient(sGrad, start: CGPoint(x: -vr, y: -vr), end: CGPoint(x: vr, y: vr), options: [])
        ctx.restoreGState()
    }
}
// Amber cinema lens center
let lr: CGFloat = 72
let sunColors = [hexColor(0xFFE285), hexColor(0xF59E0B), hexColor(0xD97706)] as CFArray
if let suGrad = CGGradient(colorsSpace: colorSpace, colors: sunColors, locations: [0.0, 0.5, 1.0]) {
    ctx.saveGState()
    ctx.addArc(center: vc, radius: lr, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.clip()
    ctx.drawLinearGradient(suGrad, start: CGPoint(x: 512, y: vc.y + lr), end: CGPoint(x: 512, y: vc.y - lr), options: [])
    
    // Cinema film aperture frame in center
    let fw: CGFloat = 46
    let fh: CGFloat = 52
    let fRect = CGRect(x: 512 - fw/2, y: vc.y - fh/2, width: fw, height: fh)
    let fPath = CGPath(roundedRect: fRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
    ctx.setFillColor(hexColor(0x0C0D12, alpha: 0.95))
    ctx.addPath(fPath)
    ctx.fillPath()
    
    // Inner projector light frame
    let inRect = fRect.insetBy(dx: 6, dy: 7)
    let inPath = CGPath(roundedRect: inRect, cornerWidth: 4, cornerHeight: 4, transform: nil)
    ctx.setFillColor(hexColor(0xFFECA8))
    ctx.addPath(inPath)
    ctx.fillPath()

    // Sprockets on left & right of aperture
    for py in [vc.y - 14, vc.y + 6] {
        let p1 = CGRect(x: fRect.minX + 2, y: py, width: 2.5, height: 5)
        let p2 = CGRect(x: fRect.maxX - 4.5, y: py, width: 2.5, height: 5)
        ctx.setFillColor(hexColor(0x0C0D12, alpha: 0.7))
        ctx.fill(p1)
        ctx.fill(p2)
    }
    
    ctx.restoreGState()
}
ctx.restoreGState() // end vinyl

// --- B. HORIZONTAL FLOATING OPEN BOOK (Literature) ---
let bx: CGFloat = 512
let by: CGFloat = 335
let pw: CGFloat = 245
let ph: CGFloat = 165

// Left Page
let lp = CGMutablePath()
lp.move(to: CGPoint(x: bx - 4, y: by + 20))
lp.addCurve(to: CGPoint(x: bx - pw, y: by + ph), control1: CGPoint(x: bx - 75, y: by + 95), control2: CGPoint(x: bx - 165, y: by + ph + 8))
lp.addLine(to: CGPoint(x: bx - pw + 18, y: by + 42))
lp.addCurve(to: CGPoint(x: bx - 4, y: by - 12), control1: CGPoint(x: bx - 145, y: by + 32), control2: CGPoint(x: bx - 60, y: by - 6))
lp.closeSubpath()

// Right Page
let rp = CGMutablePath()
rp.move(to: CGPoint(x: bx + 4, y: by + 20))
rp.addCurve(to: CGPoint(x: bx + pw, y: by + ph), control1: CGPoint(x: bx + 75, y: by + 95), control2: CGPoint(x: bx + 165, y: by + ph + 8))
rp.addLine(to: CGPoint(x: bx + pw - 18, y: by + 42))
rp.addCurve(to: CGPoint(x: bx + 4, y: by - 12), control1: CGPoint(x: bx + 145, y: by + 32), control2: CGPoint(x: bx + 60, y: by - 6))
rp.closeSubpath()

// Drop shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 32, color: rgb(0, 0, 0, 0.48))
ctx.setFillColor(rgb(0, 0, 0, 0.85))
ctx.addPath(lp)
ctx.addPath(rp)
ctx.fillPath()
ctx.restoreGState()

// Fill pages with pristine white/frosted platinum
let pageGradColors = [hexColor(0xFFFFFF), hexColor(0xF4F7FC), hexColor(0xD9E2F2)] as CFArray
if let pGrad = CGGradient(colorsSpace: colorSpace, colors: pageGradColors, locations: [0.0, 0.5, 1.0]) {
    // Left
    ctx.saveGState()
    ctx.addPath(lp)
    ctx.clip()
    ctx.drawLinearGradient(pGrad, start: CGPoint(x: bx - pw, y: by + ph), end: CGPoint(x: bx, y: by), options: [])
    ctx.setLineWidth(2.0)
    ctx.setStrokeColor(rgb(1, 1, 1, 0.95))
    ctx.addPath(lp)
    ctx.strokePath()

    // Subtle embossed lines on left page
    ctx.setLineWidth(1.4)
    ctx.setStrokeColor(hexColor(0xC2CEE4, alpha: 0.6))
    ctx.move(to: CGPoint(x: bx - pw + 60, y: by + ph - 42))
    ctx.addLine(to: CGPoint(x: bx - 40, y: by + 50))
    ctx.strokePath()
    ctx.move(to: CGPoint(x: bx - pw + 70, y: by + ph - 62))
    ctx.addLine(to: CGPoint(x: bx - 40, y: by + 32))
    ctx.strokePath()
    ctx.restoreGState()

    // Right
    ctx.saveGState()
    ctx.addPath(rp)
    ctx.clip()
    ctx.drawLinearGradient(pGrad, start: CGPoint(x: bx + pw, y: by + ph), end: CGPoint(x: bx, y: by), options: [])
    ctx.setLineWidth(2.0)
    ctx.setStrokeColor(rgb(1, 1, 1, 0.95))
    ctx.addPath(rp)
    ctx.strokePath()

    // Subtle embossed lines on right page
    ctx.setLineWidth(1.4)
    ctx.setStrokeColor(hexColor(0xC2CEE4, alpha: 0.6))
    ctx.move(to: CGPoint(x: bx + 40, y: by + 50))
    ctx.addLine(to: CGPoint(x: bx + pw - 60, y: by + ph - 42))
    ctx.strokePath()
    ctx.move(to: CGPoint(x: bx + 40, y: by + 32))
    ctx.addLine(to: CGPoint(x: bx + pw - 70, y: by + ph - 62))
    ctx.strokePath()
    ctx.restoreGState()
}

// Golden Bookmark Ribbon
let ribbon = CGMutablePath()
ribbon.move(to: CGPoint(x: bx - 12, y: by + 18))
ribbon.addLine(to: CGPoint(x: bx + 12, y: by + 18))
ribbon.addCurve(to: CGPoint(x: bx + 10, y: by - 85), control1: CGPoint(x: bx + 14, y: by - 32), control2: CGPoint(x: bx + 8, y: by - 65))
// swallow cut
ribbon.addLine(to: CGPoint(x: bx, y: by - 70))
ribbon.addLine(to: CGPoint(x: bx - 10, y: by - 85))
ribbon.addCurve(to: CGPoint(x: bx - 12, y: by + 18), control1: CGPoint(x: bx - 8, y: by - 65), control2: CGPoint(x: bx - 14, y: by - 32))
ribbon.closeSubpath()

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 14, color: rgb(0, 0, 0, 0.35))
let ribColors = [hexColor(0xFFD573), hexColor(0xF59E0B), hexColor(0xD97706)] as CFArray
if let rGrad = CGGradient(colorsSpace: colorSpace, colors: ribColors, locations: [0.0, 0.5, 1.0]) {
    ctx.addPath(ribbon)
    ctx.clip()
    ctx.drawLinearGradient(rGrad, start: CGPoint(x: bx, y: by + 18), end: CGPoint(x: bx, y: by - 85), options: [])
}
ctx.restoreGState()

// -------------------------------------------------------------------------
// 5. Apple Standard Squircle Specular Rim
// -------------------------------------------------------------------------
ctx.restoreGState() // end squircle clip

ctx.saveGState()
ctx.addPath(squirclePath)
ctx.clip()

let rimColors = [
    rgb(1, 1, 1, 0.65), // Top specular rim highlight
    rgb(1, 1, 1, 0.15),
    rgb(0, 0, 0, 0.05),
    rgb(0, 0, 0, 0.25)  // Bottom edge shadow
] as CFArray
if let rimGrad = CGGradient(colorsSpace: colorSpace, colors: rimColors, locations: [0.0, 0.2, 0.8, 1.0]) {
    ctx.setLineWidth(3.0)
    ctx.addPath(squirclePath)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    ctx.drawLinearGradient(rimGrad,
                           start: CGPoint(x: 512, y: 924),
                           end: CGPoint(x: 512, y: 100),
                           options: [])
}
ctx.restoreGState()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Failed to encode PNG")
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/icon.png"
try png.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
print("Successfully generated modern minimalist icon at: \(outputPath)")
