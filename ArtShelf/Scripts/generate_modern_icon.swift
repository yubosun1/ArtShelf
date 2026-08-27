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

// Clear canvas
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

// 1. Apple Standard macOS Squircle Geometry (824x824 centered in 1024x1024)
let plateRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let cornerRadius: CGFloat = 185.0
let squirclePath = CGPath(roundedRect: plateRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

// 2. Dock Ambient Drop Shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -26), blur: 36, color: rgb(0, 0, 0, 0.40))
ctx.setFillColor(rgb(0, 0, 0, 1.0))
ctx.addPath(squirclePath)
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 14, color: rgb(0, 0, 0, 0.25))
ctx.setFillColor(rgb(0, 0, 0, 1.0))
ctx.addPath(squirclePath)
ctx.fillPath()
ctx.restoreGState()

// 3. Squircle Background: Apple Electric Klein Indigo Gradient
ctx.saveGState()
ctx.addPath(squirclePath)
ctx.clip()

let bgColors = [
    hexColor(0x3B64F2), // Top: vibrant royal electric indigo
    hexColor(0x2244BC), // Mid: rich deep ultramarine
    hexColor(0x11237A)  // Bottom: midnight deep sapphire
] as CFArray
if let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 0.52, 1.0]) {
    ctx.drawLinearGradient(bgGrad,
                           start: CGPoint(x: 512, y: 924),
                           end: CGPoint(x: 512, y: 100),
                           options: [])
}

// Subtle top ambient spotlight
let glowColors = [
    rgb(1, 1, 1, 0.25),
    rgb(0.55, 0.75, 1.0, 0.08),
    rgb(0, 0, 0, 0.0)
] as CFArray
if let glowGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 0.45, 1.0]) {
    ctx.drawRadialGradient(glowGrad,
                           startCenter: CGPoint(x: 512, y: 880),
                           startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 880),
                           endRadius: 540,
                           options: [])
}

// -------------------------------------------------------------------------
// 4. Central Composition: Floating Minimalist Media Atelier
// -------------------------------------------------------------------------

// --- A. FLOATING HORIZONTAL SHELF PLINTH (Base) ---
let shelfWidth: CGFloat = 580
let shelfHeight: CGFloat = 20
let shelfX: CGFloat = 512 - shelfWidth / 2
let shelfY: CGFloat = 330
let shelfRect = CGRect(x: shelfX, y: shelfY, width: shelfWidth, height: shelfHeight)
let shelfPath = CGPath(roundedRect: shelfRect, cornerWidth: 10, cornerHeight: 10, transform: nil)

// Shelf Shadow below
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 24, color: rgb(0, 0, 0, 0.55))
ctx.setFillColor(hexColor(0x060B20))
ctx.addPath(shelfPath)
ctx.fillPath()
ctx.restoreGState()

// Shelf Body (Frosted Pure Platinum White / Titanium Glass)
ctx.saveGState()
ctx.addPath(shelfPath)
ctx.clip()
let shelfColors = [
    rgb(1, 1, 1, 0.95),
    rgb(0.90, 0.93, 1.0, 0.85),
    rgb(0.75, 0.80, 0.92, 0.80)
] as CFArray
if let sGrad = CGGradient(colorsSpace: colorSpace, colors: shelfColors, locations: [0.0, 0.5, 1.0]) {
    ctx.drawLinearGradient(sGrad,
                           start: CGPoint(x: 512, y: shelfY + shelfHeight),
                           end: CGPoint(x: 512, y: shelfY),
                           options: [])
}
ctx.restoreGState()

// Shelf top specular line
ctx.saveGState()
ctx.setLineWidth(1.6)
ctx.setStrokeColor(rgb(1, 1, 1, 0.95))
ctx.move(to: CGPoint(x: shelfX + 10, y: shelfY + shelfHeight - 0.8))
ctx.addLine(to: CGPoint(x: shelfX + shelfWidth - 10, y: shelfY + shelfHeight - 0.8))
ctx.strokePath()
ctx.restoreGState()

// --- B. VINYL RECORD (Music) ---
// Positioned on the right side of the shelf
let vinylCenter = CGPoint(x: 565, y: 535)
let vinylRadius: CGFloat = 195

// Vinyl drop shadow onto background
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 6, height: -16), blur: 28, color: rgb(0, 0, 0, 0.50))
ctx.addArc(center: vinylCenter, radius: vinylRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.setFillColor(hexColor(0x08090C))
ctx.fillPath()
ctx.restoreGState()

// Vinyl disc body
ctx.saveGState()
ctx.addArc(center: vinylCenter, radius: vinylRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.clip()

// Jet-black disc gradient
let discColors = [
    hexColor(0x282B34),
    hexColor(0x141518),
    hexColor(0x090A0C)
] as CFArray
if let discGrad = CGGradient(colorsSpace: colorSpace, colors: discColors, locations: [0.0, 0.5, 1.0]) {
    ctx.drawLinearGradient(discGrad,
                           start: CGPoint(x: vinylCenter.x - vinylRadius, y: vinylCenter.y + vinylRadius),
                           end: CGPoint(x: vinylCenter.x + vinylRadius, y: vinylCenter.y - vinylRadius),
                           options: [])
}

// Precision micro-groove arcs
for r in stride(from: CGFloat(72), to: vinylRadius - 6, by: 6.0) {
    ctx.setLineWidth(1.0)
    let alpha = (Int(r) % 12 == 0) ? 0.26 : 0.08
    ctx.setStrokeColor(rgb(1, 1, 1, CGFloat(alpha)))
    ctx.addArc(center: vinylCenter, radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()
}

// Iridescent dual-beam specular sheen
let sheenColors = [
    rgb(1, 1, 1, 0.0),
    rgb(0.65, 0.85, 1.0, 0.26),
    rgb(1, 0.85, 0.65, 0.22),
    rgb(1, 1, 1, 0.0)
] as CFArray
if let sheenGrad = CGGradient(colorsSpace: colorSpace, colors: sheenColors, locations: [0.0, 0.46, 0.54, 1.0]) {
    for rot in [0.72, 2.35] {
        ctx.saveGState()
        ctx.translateBy(x: vinylCenter.x, y: vinylCenter.y)
        ctx.rotate(by: CGFloat(rot))
        ctx.drawLinearGradient(sheenGrad,
                               start: CGPoint(x: -vinylRadius, y: -vinylRadius),
                               end: CGPoint(x: vinylRadius, y: vinylRadius),
                               options: [])
        ctx.restoreGState()
    }
}

// Spindle hole
ctx.setFillColor(hexColor(0x090A0C))
ctx.addArc(center: vinylCenter, radius: 14, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.fillPath()
ctx.setLineWidth(1.2)
ctx.setStrokeColor(rgb(1, 1, 1, 0.4))
ctx.strokePath()

ctx.restoreGState() // end vinyl clip

// --- C. CELLULOID FILM FRAME (Cinema - Glowing Amber Window) ---
// Overlapping the vinyl record's center
let filmX: CGFloat = 525
let filmY: CGFloat = 485
let filmW: CGFloat = 82
let filmH: CGFloat = 98
let filmRect = CGRect(x: filmX, y: filmY, width: filmW, height: filmH)
let filmPath = CGPath(roundedRect: filmRect, cornerWidth: 12, cornerHeight: 12, transform: nil)

// Warm golden bloom
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 0), blur: 30, color: hexColor(0xF59E0B, alpha: 0.80))
ctx.setFillColor(hexColor(0xF59E0B))
ctx.addPath(filmPath)
ctx.fillPath()
ctx.restoreGState()

// Film Frame Body
ctx.saveGState()
ctx.addPath(filmPath)
ctx.clip()
let filmColors = [
    hexColor(0xFFDE73),
    hexColor(0xF59E0B),
    hexColor(0xD97706)
] as CFArray
if let fGrad = CGGradient(colorsSpace: colorSpace, colors: filmColors, locations: [0.0, 0.5, 1.0]) {
    ctx.drawLinearGradient(fGrad,
                           start: CGPoint(x: filmX, y: filmY + filmH),
                           end: CGPoint(x: filmX, y: filmY),
                           options: [])
}

// Inner projection window
let projRect = filmRect.insetBy(dx: 11, dy: 13)
let projPath = CGPath(roundedRect: projRect, cornerWidth: 6, cornerHeight: 6, transform: nil)
ctx.setFillColor(hexColor(0x181410, alpha: 0.92))
ctx.addPath(projPath)
ctx.fillPath()

// Inner warm projector glow
let innerGlow = projRect.insetBy(dx: 7, dy: 8)
let innerPath = CGPath(roundedRect: innerGlow, cornerWidth: 3, cornerHeight: 3, transform: nil)
ctx.setFillColor(hexColor(0xFFEAA0, alpha: 0.95))
ctx.addPath(innerPath)
ctx.fillPath()

// Sprocket perforations
for py in stride(from: filmRect.minY + 16, to: filmRect.maxY - 10, by: 20) {
    let pL = CGRect(x: filmRect.minX + 3.5, y: py, width: 4, height: 7)
    let pR = CGRect(x: filmRect.maxX - 7.5, y: py, width: 4, height: 7)
    ctx.setFillColor(hexColor(0x181410, alpha: 0.65))
    ctx.fill(pL)
    ctx.fill(pR)
}
ctx.restoreGState() // end film clip

// Film Bevel Border
ctx.saveGState()
ctx.setLineWidth(2.0)
ctx.setStrokeColor(rgb(1, 1, 1, 0.85))
ctx.addPath(filmPath)
ctx.strokePath()
ctx.restoreGState()

// --- D. MODERN HARDCOVER ART BOOK (Literature) ---
// Standing on the left side of the shelf, partially overlapping the vinyl
let bookX: CGFloat = 300
let bookY: CGFloat = shelfY + shelfHeight - 4
let bookW: CGFloat = 162
let bookH: CGFloat = 350
let bookRect = CGRect(x: bookX, y: bookY, width: bookW, height: bookH)
let bookCorner: CGFloat = 10
let bookPath = CGPath(roundedRect: bookRect, cornerWidth: bookCorner, cornerHeight: bookCorner, transform: nil)

// Book Drop Shadow onto vinyl and shelf
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 12, height: -16), blur: 28, color: rgb(0, 0, 0, 0.45))
ctx.setFillColor(hexColor(0x101524))
ctx.addPath(bookPath)
ctx.fillPath()
ctx.restoreGState()

// Book Cover Body (Pure Architectural Platinum Ivory with subtle warmth)
ctx.saveGState()
ctx.addPath(bookPath)
ctx.clip()

let bookCoverColors = [
    hexColor(0xFFFFFF), // Top pure highlight
    hexColor(0xF0ECE1), // Subtle warm ivory
    hexColor(0xDBD5C4)  // Base warm stone
] as CFArray
if let bGrad = CGGradient(colorsSpace: colorSpace, colors: bookCoverColors, locations: [0.0, 0.5, 1.0]) {
    ctx.drawLinearGradient(bGrad,
                           start: CGPoint(x: bookX, y: bookY + bookH),
                           end: CGPoint(x: bookX + bookW, y: bookY),
                           options: [])
}

// Spine Ridge on Left
let spineW: CGFloat = 24
let spineRect = CGRect(x: bookX, y: bookY, width: spineW, height: bookH)
let spineColors = [
    hexColor(0xEAE4D5, alpha: 0.9),
    hexColor(0xD2C9B6, alpha: 0.5),
    hexColor(0xB5AB94, alpha: 0.9)
] as CFArray
if let spineGrad = CGGradient(colorsSpace: colorSpace, colors: spineColors, locations: [0.0, 0.5, 1.0]) {
    ctx.drawLinearGradient(spineGrad,
                           start: CGPoint(x: bookX, y: bookY),
                           end: CGPoint(x: bookX + spineW, y: bookY),
                           options: [])
}

// Embossed Gold Foil Accent on Cover
let goldX = bookX + spineW + 16
let goldW = bookW - spineW - 30

// Gold vertical bar
ctx.setLineWidth(2.2)
ctx.setStrokeColor(hexColor(0xDE9B2A, alpha: 0.95))
ctx.move(to: CGPoint(x: goldX + 6, y: bookY + 40))
ctx.addLine(to: CGPoint(x: goldX + 6, y: bookY + bookH - 40))
ctx.strokePath()

// Minimalist title lines
for ly in [bookY + bookH - 90, bookY + bookH - 110, bookY + bookH - 130] {
    ctx.setLineWidth(1.8)
    ctx.move(to: CGPoint(x: goldX + 20, y: ly))
    ctx.addLine(to: CGPoint(x: goldX + goldW, y: ly))
    ctx.strokePath()
}

// Right Page Edge Strip (layered paper look)
let pageStrip = CGRect(x: bookX + bookW - 10, y: bookY + 4, width: 8, height: bookH - 8)
ctx.setFillColor(hexColor(0xF5EFE3))
ctx.fill(pageStrip)
for py in stride(from: bookY + 12, to: bookY + bookH - 12, by: 4.5) {
    ctx.setLineWidth(0.6)
    ctx.setStrokeColor(hexColor(0xC4B89D, alpha: 0.7))
    ctx.move(to: CGPoint(x: bookX + bookW - 10, y: py))
    ctx.addLine(to: CGPoint(x: bookX + bookW - 2, y: py))
    ctx.strokePath()
}

// Book Border Specular
ctx.setLineWidth(1.6)
ctx.setStrokeColor(rgb(1, 1, 1, 0.85))
ctx.addPath(bookPath)
ctx.strokePath()

ctx.restoreGState() // end book clip

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
    rgb(0, 0, 0, 0.35)  // Bottom edge shadow
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
