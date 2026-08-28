import AppKit
import Foundation
import CoreGraphics

let side: CGFloat = 1024
let size = NSSize(width: side, height: side)
let colorSpace = CGColorSpaceCreateDeviceRGB()

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

let plateRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let cornerRadius: CGFloat = 185.0
let squirclePath = CGPath(roundedRect: plateRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

func drawStandardSquircleShadow(in ctx: CGContext, lightMode: Bool) {
    ctx.saveGState()
    let shadowAlpha: CGFloat = lightMode ? 0.22 : 0.36
    ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 34, color: rgb(0, 0, 0, shadowAlpha))
    ctx.setFillColor(rgb(0, 0, 0, 1))
    ctx.addPath(squirclePath)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    let ambientAlpha: CGFloat = lightMode ? 0.14 : 0.20
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 14, color: rgb(0, 0, 0, ambientAlpha))
    ctx.setFillColor(rgb(0, 0, 0, 1))
    ctx.addPath(squirclePath)
    ctx.fillPath()
    ctx.restoreGState()
}

func drawSquircleRim(in ctx: CGContext, lightMode: Bool) {
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()

    let rimColors: CFArray
    if lightMode {
        rimColors = [
            rgb(1, 1, 1, 0.95),
            rgb(1, 1, 1, 0.40),
            rgb(0, 0, 0, 0.03),
            rgb(0, 0, 0, 0.18)
        ] as CFArray
    } else {
        rimColors = [
            rgb(1, 1, 1, 0.65),
            rgb(1, 1, 1, 0.12),
            rgb(0, 0, 0, 0.05),
            rgb(0, 0, 0, 0.30)
        ] as CFArray
    }
    
    if let rimGrad = CGGradient(colorsSpace: colorSpace, colors: rimColors, locations: [0.0, 0.15, 0.85, 1.0]) {
        ctx.setLineWidth(3.0)
        ctx.addPath(squirclePath)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        ctx.drawLinearGradient(rimGrad, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    }
    ctx.restoreGState()
}

func drawSparkleStar(in ctx: CGContext, center: CGPoint, radius: CGFloat, color: CGColor) {
    let path = CGMutablePath()
    let innerR = radius * 0.22
    for i in 0..<8 {
        let r = (i % 2 == 0) ? radius : innerR
        let angle = CGFloat(i) * .pi / 4.0 - .pi / 2.0
        let pt = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
        if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
    }
    path.closeSubpath()
    
    ctx.saveGState()
    ctx.setFillColor(color)
    ctx.addPath(path)
    ctx.fillPath()
    ctx.restoreGState()
}

func saveImage(_ image: NSImage, to path: String) {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Failed to encode PNG for \(path)")
    }
    try! png.write(to: URL(fileURLWithPath: path), options: .atomic)
    print("Saved: \(path)")
}

enum IconTheme {
    case ivory      // 象牙画廊纯白 (默认)
    case sky        // 晴空微晶淡蓝
    case rose       // 珍珠粉晕暖白
    case dark       // 深空暮夜棱镜
}

func generatePrismIcon(theme: IconTheme) -> NSImage {
    let img = NSImage(size: size)
    img.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError() }
    ctx.clear(CGRect(x: 0, y: 0, width: side, height: side))

    let isLight = theme != .dark
    drawStandardSquircleShadow(in: ctx, lightMode: isLight)

    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()

    // 1. 底板配色
    let bgColors: CFArray
    let ambientGlow: CFArray
    let legColor: CGColor
    let legHighlight: CGColor
    let shelfTop: CGColor
    let shelfBottom: CGColor
    let hingeColor: CGColor

    switch theme {
    case .ivory:
        bgColors = [hexColor(0xFFFFFF), hexColor(0xF5F6F9), hexColor(0xE8EBF2)] as CFArray
        ambientGlow = [rgb(1, 1, 1, 0.9), rgb(1, 1, 1, 0.0)] as CFArray
        legColor = hexColor(0x505769)
        legHighlight = rgb(1, 1, 1, 0.7)
        shelfTop = hexColor(0x3B4152)
        shelfBottom = hexColor(0x232733)
        hingeColor = hexColor(0xF59E0B)

    case .sky:
        bgColors = [hexColor(0xFAFCFF), hexColor(0xECF3FE), hexColor(0xDCE8FA)] as CFArray
        ambientGlow = [hexColor(0x93C5FD, alpha: 0.35), rgb(1, 1, 1, 0.0)] as CFArray
        legColor = hexColor(0x3B4D6B)
        legHighlight = hexColor(0xE0ECFC)
        shelfTop = hexColor(0x2A3B58)
        shelfBottom = hexColor(0x18253A)
        hingeColor = hexColor(0x38BDF8)

    case .rose:
        bgColors = [hexColor(0xFFFBFC), hexColor(0xFDF0F4), hexColor(0xF7DFE8)] as CFArray
        ambientGlow = [hexColor(0xF472B6, alpha: 0.25), rgb(1, 1, 1, 0.0)] as CFArray
        legColor = hexColor(0x6E4B5E)
        legHighlight = hexColor(0xFCE7F3)
        shelfTop = hexColor(0x543245)
        shelfBottom = hexColor(0x381B2B)
        hingeColor = hexColor(0xFB7185)

    case .dark:
        bgColors = [hexColor(0x181A22), hexColor(0x101117), hexColor(0x090A0D)] as CFArray
        ambientGlow = [hexColor(0x3B82F6, alpha: 0.25), rgb(0, 0, 0, 0.0)] as CFArray
        legColor = hexColor(0x323746)
        legHighlight = hexColor(0x4A5364)
        shelfTop = hexColor(0x282C37)
        shelfBottom = hexColor(0x191B22)
        hingeColor = hexColor(0xFBE08C)
    }

    if let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 0.55, 1.0]) {
        ctx.drawLinearGradient(bgGrad, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    }
    if let aGrad = CGGradient(colorsSpace: colorSpace, colors: ambientGlow, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(aGrad, startCenter: CGPoint(x: 512, y: 880), startRadius: 0, endCenter: CGPoint(x: 512, y: 880), endRadius: 500, options: [])
    }

    // 2. 画架 A 字立柱
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 20, color: rgb(0, 0, 0, isLight ? 0.18 : 0.5))
    ctx.setLineWidth(20.0)
    ctx.setStrokeColor(legColor)
    ctx.setLineCap(.round)

    ctx.move(to: CGPoint(x: 512 - 26, y: 785))
    ctx.addLine(to: CGPoint(x: 232, y: 195))
    ctx.strokePath()

    ctx.move(to: CGPoint(x: 512 + 26, y: 785))
    ctx.addLine(to: CGPoint(x: 792, y: 195))
    ctx.strokePath()

    ctx.setLineWidth(2.5)
    ctx.setStrokeColor(legHighlight)
    ctx.move(to: CGPoint(x: 512 - 32, y: 775))
    ctx.addLine(to: CGPoint(x: 226, y: 195))
    ctx.strokePath()
    ctx.move(to: CGPoint(x: 512 + 22, y: 775))
    ctx.addLine(to: CGPoint(x: 786, y: 195))
    ctx.strokePath()
    ctx.restoreGState()

    // 铰链
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 12, color: rgb(0, 0, 0, 0.25))
    ctx.setFillColor(hingeColor)
    ctx.addArc(center: CGPoint(x: 512, y: 785), radius: 17, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.fillPath()
    ctx.setFillColor(rgb(1, 1, 1, 0.8))
    ctx.addArc(center: CGPoint(x: 508, y: 790), radius: 5, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.fillPath()
    ctx.restoreGState()

    // 3. 棱镜玻璃板
    let prismRect = CGRect(x: 272, y: 310, width: 480, height: 380)
    let prismPath = CGPath(roundedRect: prismRect, cornerWidth: 32, cornerHeight: 32, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 44, color: hexColor(0x3B82F6, alpha: isLight ? 0.26 : 0.35))
    ctx.setFillColor(rgb(0, 0, 0, isLight ? 0.15 : 0.8))
    ctx.addPath(prismPath)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(prismPath)
    ctx.clip()

    let spectrumColors = [
        hexColor(0xFF2E63), // 闪耀元气红粉
        hexColor(0x9D4EDD), // 梦幻极光炫紫
        hexColor(0x00A8FF), // 晶澈晴空电蓝
        hexColor(0x00E676), // 鲜明翡翠青绿
        hexColor(0xFFC048)  // 典藏暖耀纯金
    ] as CFArray
    if let sg = CGGradient(colorsSpace: colorSpace, colors: spectrumColors, locations: [0.0, 0.26, 0.52, 0.76, 1.0]) {
        ctx.drawLinearGradient(sg, start: CGPoint(x: prismRect.minX - 30, y: prismRect.maxY + 30),
                                  end: CGPoint(x: prismRect.maxX + 30, y: prismRect.minY - 30), options: [])
    }

    let glareColors = [
        rgb(1, 1, 1, 0.65),
        rgb(1, 1, 1, 0.20),
        rgb(1, 1, 1, 0.0),
        rgb(1, 1, 1, 0.15)
    ] as CFArray
    if let glGrad = CGGradient(colorsSpace: colorSpace, colors: glareColors, locations: [0.0, 0.35, 0.65, 1.0]) {
        ctx.drawLinearGradient(glGrad, start: CGPoint(x: prismRect.minX, y: prismRect.maxY),
                                      end: CGPoint(x: prismRect.maxX, y: prismRect.minY), options: [])
    }

    // 内部远山光影
    let innerWave = CGMutablePath()
    innerWave.move(to: CGPoint(x: prismRect.minX, y: prismRect.minY))
    innerWave.addLine(to: CGPoint(x: prismRect.minX, y: prismRect.minY + 110))
    innerWave.addCurve(to: CGPoint(x: prismRect.midX + 40, y: prismRect.minY + 135),
                       control1: CGPoint(x: prismRect.minX + 80, y: prismRect.minY + 80),
                       control2: CGPoint(x: prismRect.midX - 40, y: prismRect.minY + 160))
    innerWave.addCurve(to: CGPoint(x: prismRect.maxX, y: prismRect.minY + 90),
                       control1: CGPoint(x: prismRect.midX + 110, y: prismRect.minY + 110),
                       control2: CGPoint(x: prismRect.maxX - 60, y: prismRect.minY + 130))
    innerWave.addLine(to: CGPoint(x: prismRect.maxX, y: prismRect.minY))
    innerWave.closeSubpath()
    ctx.setFillColor(rgb(1, 1, 1, isLight ? 0.18 : 0.22))
    ctx.addPath(innerWave)
    ctx.fillPath()

    ctx.setLineWidth(3.0)
    ctx.setStrokeColor(rgb(1, 1, 1, 0.92))
    ctx.addPath(prismPath)
    ctx.strokePath()
    ctx.restoreGState()

    // 4. 托板
    let barRect = CGRect(x: 212, y: 290, width: 600, height: 34)
    let barPath = CGPath(roundedRect: barRect, cornerWidth: 12, cornerHeight: 12, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -16), blur: 24, color: rgb(0, 0, 0, isLight ? 0.35 : 0.6))
    ctx.setFillColor(shelfBottom)
    ctx.addPath(barPath)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(barPath)
    ctx.clip()
    let barGrad = [shelfTop, shelfBottom] as CFArray
    if let bg = CGGradient(colorsSpace: colorSpace, colors: barGrad, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: barRect.maxY), end: CGPoint(x: 512, y: barRect.minY), options: [])
    }
    ctx.setStrokeColor(rgb(1, 1, 1, 0.90))
    ctx.setLineWidth(2.5)
    ctx.move(to: CGPoint(x: barRect.minX + 8, y: barRect.maxY - 1))
    ctx.addLine(to: CGPoint(x: barRect.maxX - 8, y: barRect.maxY - 1))
    ctx.strokePath()
    ctx.restoreGState()

    // 5. 托板星芒
    let starCenter = CGPoint(x: 512, y: barRect.midY)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 0), blur: 10, color: hexColor(0xFFE285, alpha: 0.9))
    drawSparkleStar(in: ctx, center: starCenter, radius: 15, color: hexColor(0xFFF9D6))
    ctx.restoreGState()

    ctx.restoreGState() // end squircle clip

    drawSquircleRim(in: ctx, lightMode: isLight)
    img.unlockFocus()
    return img
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "ArtShelf/Resources/Icons"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let ivory = generatePrismIcon(theme: .ivory)
saveImage(ivory, to: "\(outDir)/prism_ivory.png")

let sky = generatePrismIcon(theme: .sky)
saveImage(sky, to: "\(outDir)/prism_sky.png")

let rose = generatePrismIcon(theme: .rose)
saveImage(rose, to: "\(outDir)/prism_rose.png")

let dark = generatePrismIcon(theme: .dark)
saveImage(dark, to: "\(outDir)/prism_dark.png")

print("Official app icons generated successfully into \(outDir)!")
