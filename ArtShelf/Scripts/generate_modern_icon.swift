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

// 1. Clear background
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

// 2. Apple Standard macOS Squircle Geometry (824x824 centered in 1024x1024)
let plateRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let cornerRadius: CGFloat = 185.0
let squirclePath = CGPath(roundedRect: plateRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

// 3. Drop Shadow for the Squircle (macOS Dock elevation)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 36, color: rgb(0, 0, 0, 0.35))
ctx.setFillColor(rgb(0.08, 0.09, 0.11, 1.0))
ctx.addPath(squirclePath)
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 16, color: rgb(0, 0, 0, 0.25))
ctx.setFillColor(rgb(0.08, 0.09, 0.11, 1.0))
ctx.addPath(squirclePath)
ctx.fillPath()
ctx.restoreGState()

// 4. Clip to squircle for internal drawing
ctx.saveGState()
ctx.addPath(squirclePath)
ctx.clip()

// Background: Deep, rich midnight gallery tone with subtle radial warmth
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bgColors = [
    hexColor(0x282C37), // Top-left subtle deep blue-slate
    hexColor(0x1B1D24), // Mid slate
    hexColor(0x111216)  // Bottom-right deep obsidian
] as CFArray
let bgLocations: [CGFloat] = [0.0, 0.55, 1.0]
if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgLocations) {
    ctx.drawLinearGradient(bgGradient,
                           start: CGPoint(x: 200, y: 924),
                           end: CGPoint(x: 824, y: 100),
                           options: [])
}

// Smooth top ambient spotlight (without point artifact)
let spotColors = [
    rgb(1, 1, 1, 0.08),
    rgb(1, 1, 1, 0.03),
    rgb(1, 1, 1, 0.0)
] as CFArray
if let radialGradient = CGGradient(colorsSpace: colorSpace, colors: spotColors, locations: [0.0, 0.5, 1.0]) {
    ctx.drawRadialGradient(radialGradient,
                           startCenter: CGPoint(x: 512, y: 924),
                           startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 924),
                           endRadius: 520,
                           options: [])
}

// -------------------------------------------------------------------------
// 5. Bookshelf Plinth (Horizontal Base)
// -------------------------------------------------------------------------
let shelfY: CGFloat = 280
let shelfHeight: CGFloat = 46
let shelfRect = CGRect(x: 100, y: shelfY - shelfHeight, width: 824, height: shelfHeight)

// Shelf Shadow below
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 20, color: rgb(0, 0, 0, 0.55))
ctx.setFillColor(hexColor(0x1E1611))
ctx.fill(shelfRect)
ctx.restoreGState()

// Shelf body gradient (fine dark walnut tone)
let woodColors = [
    hexColor(0x564131),
    hexColor(0x3B2C21),
    hexColor(0x261C14)
] as CFArray
if let woodGrad = CGGradient(colorsSpace: colorSpace, colors: woodColors, locations: [0.0, 0.4, 1.0]) {
    ctx.drawLinearGradient(woodGrad,
                           start: CGPoint(x: 512, y: shelfY),
                           end: CGPoint(x: 512, y: shelfY - shelfHeight),
                           options: [])
}

// Shelf top bevel highlight (polished wood edge)
let shelfBevel = CGRect(x: 100, y: shelfY - 2.5, width: 824, height: 2.5)
ctx.setFillColor(hexColor(0x9E7E5E, alpha: 0.9))
ctx.fill(shelfBevel)

// -------------------------------------------------------------------------
// 6. Artwork Elements
// -------------------------------------------------------------------------

// --- ELEMENT A: VINYL RECORD (Behind book on right) ---
let vinylCenter = CGPoint(x: 575, y: 535)
let vinylRadius: CGFloat = 218

// Vinyl drop shadow onto background
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 4, height: -16), blur: 26, color: rgb(0, 0, 0, 0.52))
ctx.addArc(center: vinylCenter, radius: vinylRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.setFillColor(hexColor(0x0C0D0E))
ctx.fillPath()
ctx.restoreGState()

// Vinyl disc body
ctx.saveGState()
ctx.addArc(center: vinylCenter, radius: vinylRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.clip()

// Base disc color
ctx.setFillColor(hexColor(0x131418))
ctx.fill(CGRect(x: vinylCenter.x - vinylRadius, y: vinylCenter.y - vinylRadius, width: vinylRadius * 2, height: vinylRadius * 2))

// Concentric vinyl micro-grooves
for r in stride(from: CGFloat(94), to: vinylRadius - 6, by: 4.2) {
    ctx.setLineWidth(1.0)
    let alpha = (Int(r) % 8 == 0) ? 0.24 : 0.07
    ctx.setStrokeColor(rgb(1, 1, 1, CGFloat(alpha)))
    ctx.addArc(center: vinylCenter, radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()
}

// Radial iridescent sheen
let sheenColors = [
    rgb(1, 1, 1, 0.0),
    rgb(1, 0.88, 0.65, 0.16),
    rgb(0.65, 0.82, 1, 0.18),
    rgb(1, 1, 1, 0.0)
] as CFArray
if let sheenGrad = CGGradient(colorsSpace: colorSpace, colors: sheenColors, locations: [0.0, 0.45, 0.55, 1.0]) {
    for angle in [0.72, 2.35] {
        ctx.saveGState()
        ctx.translateBy(x: vinylCenter.x, y: vinylCenter.y)
        ctx.rotate(by: CGFloat(angle))
        ctx.drawLinearGradient(sheenGrad,
                               start: CGPoint(x: -vinylRadius, y: -vinylRadius),
                               end: CGPoint(x: vinylRadius, y: vinylRadius),
                               options: [])
        ctx.restoreGState()
    }
}

// Center record label
let labelRadius: CGFloat = 78
let labelColors = [
    hexColor(0xEB5438), // Vibrant modern coral/terracotta
    hexColor(0xBD331C)
] as CFArray
if let labelGrad = CGGradient(colorsSpace: colorSpace, colors: labelColors, locations: [0.0, 1.0]) {
    ctx.saveGState()
    ctx.addArc(center: vinylCenter, radius: labelRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.clip()
    ctx.drawLinearGradient(labelGrad,
                           start: CGPoint(x: vinylCenter.x - labelRadius, y: vinylCenter.y + labelRadius),
                           end: CGPoint(x: vinylCenter.x + labelRadius, y: vinylCenter.y - labelRadius),
                           options: [])
    
    // Golden concentric rings on label
    ctx.setLineWidth(1.8)
    ctx.setStrokeColor(hexColor(0xFFE4A0, alpha: 0.7))
    ctx.addArc(center: vinylCenter, radius: labelRadius - 16, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()
    
    ctx.setLineWidth(1.0)
    ctx.setStrokeColor(hexColor(0xFFE4A0, alpha: 0.4))
    ctx.addArc(center: vinylCenter, radius: labelRadius - 28, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()
    
    // Spindle hole
    let spindleRadius: CGFloat = 16
    ctx.setFillColor(hexColor(0x0C0D0E))
    ctx.addArc(center: vinylCenter, radius: spindleRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.fillPath()
    ctx.setLineWidth(1.5)
    ctx.setStrokeColor(rgb(1, 1, 1, 0.4))
    ctx.strokePath()
    ctx.restoreGState()
}
ctx.restoreGState() // end vinyl clip

// --- ELEMENT B: CELLULOID FILM STRIP (Cinema) ---
// Slanted at -3 degrees, leaning gently on the right
ctx.saveGState()
ctx.translateBy(x: 700, y: 280)
ctx.rotate(by: -0.045) // ~2.6 degrees tilt
ctx.translateBy(x: -700, y: -280)

let filmRect = CGRect(x: 645, y: 280, width: 125, height: 360)
let filmPath = CGPath(roundedRect: filmRect, cornerWidth: 6, cornerHeight: 6, transform: nil)

// Film shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: -8, height: -12), blur: 18, color: rgb(0, 0, 0, 0.45))
ctx.setFillColor(hexColor(0x1B1612))
ctx.addPath(filmPath)
ctx.fillPath()
ctx.restoreGState()

// Film translucent amber body
ctx.saveGState()
ctx.addPath(filmPath)
ctx.clip()

let filmColors = [
    hexColor(0x3B2516, alpha: 0.94),
    hexColor(0x4C301C, alpha: 0.96),
    hexColor(0x2B190E, alpha: 0.97)
] as CFArray
if let filmGrad = CGGradient(colorsSpace: colorSpace, colors: filmColors, locations: [0.0, 0.5, 1.0]) {
    ctx.drawLinearGradient(filmGrad, start: CGPoint(x: 645, y: 640), end: CGPoint(x: 770, y: 280), options: [])
}

// Sprocket holes along left and right
func drawFilmPerforations(startX: CGFloat, stepY: CGFloat) {
    for y in stride(from: CGFloat(295), to: 625, by: stepY) {
        let perfRect = CGRect(x: startX - 5, y: y, width: 10, height: 16)
        let perfPath = CGPath(roundedRect: perfRect, cornerWidth: 2.5, cornerHeight: 2.5, transform: nil)
        ctx.setFillColor(hexColor(0x0F0F14, alpha: 0.95))
        ctx.addPath(perfPath)
        ctx.fillPath()
        ctx.setLineWidth(0.8)
        ctx.setStrokeColor(rgb(1, 0.82, 0.55, 0.25))
        ctx.addPath(perfPath)
        ctx.strokePath()
    }
}
drawFilmPerforations(startX: 656, stepY: 28)
drawFilmPerforations(startX: 758, stepY: 28)

// Film frames (glowing cinema windows)
for frameY in stride(from: CGFloat(300), to: 600, by: 105) {
    let windowRect = CGRect(x: 668, y: frameY, width: 78, height: 92)
    let windowPath = CGPath(roundedRect: windowRect, cornerWidth: 5, cornerHeight: 5, transform: nil)
    let frameColors = [
        hexColor(0xFFBA54, alpha: 0.3),
        hexColor(0x4A2C16, alpha: 0.65)
    ] as CFArray
    if let frameGrad = CGGradient(colorsSpace: colorSpace, colors: frameColors, locations: [0.0, 1.0]) {
        ctx.saveGState()
        ctx.addPath(windowPath)
        ctx.clip()
        ctx.drawLinearGradient(frameGrad,
                               start: CGPoint(x: 707, y: frameY + 92),
                               end: CGPoint(x: 707, y: frameY),
                               options: [])
        ctx.restoreGState()
    }
    ctx.setLineWidth(1.2)
    ctx.setStrokeColor(hexColor(0xFFAC3B, alpha: 0.45))
    ctx.addPath(windowPath)
    ctx.strokePath()
}
ctx.restoreGState() // end film clip
ctx.restoreGState() // end tilt

// --- ELEMENT C: HARDCOVER ART BOOK (Foreground Masterpiece) ---
let bookX: CGFloat = 255
let bookY: CGFloat = 280
let bookWidth: CGFloat = 205
let bookHeight: CGFloat = 445
let bookRect = CGRect(x: bookX, y: bookY, width: bookWidth, height: bookHeight)

// Book drop shadow onto shelf and vinyl
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 14, height: -18), blur: 30, color: rgb(0, 0, 0, 0.58))
let bookCorner: CGFloat = 8
let bookPath = CGPath(roundedRect: bookRect, cornerWidth: bookCorner, cornerHeight: bookCorner, transform: nil)
ctx.setFillColor(hexColor(0x131E2B))
ctx.addPath(bookPath)
ctx.fillPath()
ctx.restoreGState()

// Book Cover Texture (Sapphire / Royal Midnight Blue Linen Cloth)
ctx.saveGState()
ctx.addPath(bookPath)
ctx.clip()

let bookCoverColors = [
    hexColor(0x2C4C74), // Top highlight
    hexColor(0x1E3655), // Rich Prussian blue
    hexColor(0x142337)  // Deep midnight base
] as CFArray
if let bookGrad = CGGradient(colorsSpace: colorSpace, colors: bookCoverColors, locations: [0.0, 0.45, 1.0]) {
    ctx.drawLinearGradient(bookGrad,
                           start: CGPoint(x: bookX, y: bookY + bookHeight),
                           end: CGPoint(x: bookX + bookWidth, y: bookY),
                           options: [])
}

// Book spine ridge (curved spine volume on left)
let spineWidth: CGFloat = 28
let spineRect = CGRect(x: bookX, y: bookY, width: spineWidth, height: bookHeight)
let spineColors = [
    hexColor(0x446B9E, alpha: 0.75),
    hexColor(0x192B42, alpha: 0.1),
    hexColor(0x0D1826, alpha: 0.65)
] as CFArray
if let spineGrad = CGGradient(colorsSpace: colorSpace, colors: spineColors, locations: [0.0, 0.4, 1.0]) {
    ctx.drawLinearGradient(spineGrad,
                           start: CGPoint(x: bookX, y: bookY),
                           end: CGPoint(x: bookX + spineWidth, y: bookY),
                           options: [])
}

// Embossed Gold Foil Inlay Lines on book cover (Gleaming luxury gold)
ctx.saveGState()
let goldLineX = bookX + spineWidth + 16
let goldWidth = bookWidth - spineWidth - 32
let goldLineY2 = bookY + 65

let goldColor = hexColor(0xEDC478, alpha: 0.95)
ctx.setStrokeColor(goldColor)

// Top gold title cartouche / frame
let emblemRect = CGRect(x: goldLineX, y: bookY + bookHeight - 160, width: goldWidth, height: 75)
let emblemPath = CGPath(roundedRect: emblemRect, cornerWidth: 3, cornerHeight: 3, transform: nil)
ctx.setLineWidth(2.0)
ctx.addPath(emblemPath)
ctx.strokePath()

// Decorative gold bars
for offY in [22.0, 37.0, 52.0] {
    ctx.setLineWidth(1.4)
    ctx.move(to: CGPoint(x: goldLineX + 16, y: bookY + bookHeight - 160 + offY))
    ctx.addLine(to: CGPoint(x: goldLineX + goldWidth - 16, y: bookY + bookHeight - 160 + offY))
    ctx.strokePath()
}

// Lower gold rules
ctx.setLineWidth(1.6)
ctx.move(to: CGPoint(x: goldLineX, y: goldLineY2))
ctx.addLine(to: CGPoint(x: goldLineX + goldWidth, y: goldLineY2))
ctx.strokePath()
ctx.move(to: CGPoint(x: goldLineX, y: goldLineY2 - 9))
ctx.addLine(to: CGPoint(x: goldLineX + goldWidth, y: goldLineY2 - 9))
ctx.strokePath()
ctx.restoreGState()

// Book Page Block Edge (Right side showing elegant cream page layers)
let pagesX = bookX + bookWidth - 12
let pagesRect = CGRect(x: pagesX, y: bookY + 6, width: 10, height: bookHeight - 12)
ctx.setFillColor(hexColor(0xF2EAD8))
ctx.fill(pagesRect)
for py in stride(from: bookY + 12, to: bookY + bookHeight - 14, by: 4) {
    ctx.setLineWidth(0.6)
    ctx.setStrokeColor(hexColor(0xC4B8A2, alpha: 0.65))
    ctx.move(to: CGPoint(x: pagesX, y: py))
    ctx.addLine(to: CGPoint(x: pagesX + 10, y: py))
    ctx.strokePath()
}

// Book top edge highlight
ctx.setLineWidth(1.6)
ctx.setStrokeColor(rgb(1, 1, 1, 0.35))
ctx.move(to: CGPoint(x: bookX + 2, y: bookY + bookHeight - 1))
ctx.addLine(to: CGPoint(x: bookX + bookWidth - 2, y: bookY + bookHeight - 1))
ctx.strokePath()

ctx.restoreGState() // end book clip

// --- ELEMENT D: CRIMSON SILK RIBBON BOOKMARK ---
ctx.saveGState()
let ribbonPath = CGMutablePath()
ribbonPath.move(to: CGPoint(x: bookX + 78, y: bookY + bookHeight))
ribbonPath.addCurve(to: CGPoint(x: bookX + 70, y: bookY + 180),
                    control1: CGPoint(x: bookX + 82, y: bookY + 360),
                    control2: CGPoint(x: bookX + 66, y: bookY + 240))
ribbonPath.addCurve(to: CGPoint(x: bookX + 80, y: shelfY - 32),
                    control1: CGPoint(x: bookX + 72, y: bookY + 80),
                    control2: CGPoint(x: bookX + 78, y: shelfY + 20))
ribbonPath.addLine(to: CGPoint(x: bookX + 96, y: shelfY - 30))
// Swallow-tail cut
ribbonPath.addLine(to: CGPoint(x: bookX + 88, y: shelfY - 20))
ribbonPath.addLine(to: CGPoint(x: bookX + 98, y: shelfY + 25))
ribbonPath.addCurve(to: CGPoint(x: bookX + 92, y: bookY + bookHeight),
                    control1: CGPoint(x: bookX + 87, y: bookY + 180),
                    control2: CGPoint(x: bookX + 97, y: bookY + 360))
ribbonPath.closeSubpath()

// Ribbon Shadow
ctx.setShadow(offset: CGSize(width: 4, height: -6), blur: 10, color: rgb(0, 0, 0, 0.48))
ctx.setFillColor(hexColor(0x821D12))
ctx.addPath(ribbonPath)
ctx.fillPath()
ctx.restoreGState()

// Ribbon Gradient (Rich Crimson / Scarlet Silk)
ctx.saveGState()
ctx.addPath(ribbonPath)
ctx.clip()
let ribbonColors = [
    hexColor(0xF04F3B),
    hexColor(0xCC2A1A),
    hexColor(0x8C180E)
] as CFArray
if let ribbonGrad = CGGradient(colorsSpace: colorSpace, colors: ribbonColors, locations: [0.0, 0.5, 1.0]) {
    ctx.drawLinearGradient(ribbonGrad,
                           start: CGPoint(x: bookX + 70, y: bookY + bookHeight),
                           end: CGPoint(x: bookX + 90, y: shelfY - 35),
                           options: [])
}
ctx.setLineWidth(1.2)
ctx.setStrokeColor(rgb(1, 0.75, 0.75, 0.45))
ctx.addPath(ribbonPath)
ctx.strokePath()
ctx.restoreGState()

// -------------------------------------------------------------------------
// 7. Icon Bevel Rim & Specular Polish (macOS signature)
// -------------------------------------------------------------------------
ctx.restoreGState() // end squircle clip

ctx.saveGState()
ctx.addPath(squirclePath)
ctx.clip()

let rimColors = [
    rgb(1, 1, 1, 0.32), // Bright top edge
    rgb(1, 1, 1, 0.10), // Mid
    rgb(1, 1, 1, 0.02),
    rgb(0, 0, 0, 0.40)  // Bottom edge bevel shadow
] as CFArray
if let rimGrad = CGGradient(colorsSpace: colorSpace, colors: rimColors, locations: [0.0, 0.3, 0.8, 1.0]) {
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
print("Successfully generated icon at: \(outputPath)")
