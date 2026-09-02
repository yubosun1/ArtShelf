import AppKit
import Foundation
import CoreGraphics

// generate_icons_v2.swift —— v3.1 暗房方向新图标（陈列架三类藏品 / 极简棱镜方块）
// 用法（仓库根目录）：swift ArtShelf/Scripts/generate_icons_v2.swift [输出目录]
// 默认输出到 ArtShelf/Resources/Icons/，与 v1 四款棱镜图标并列，供设置内切换。

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

// MARK: - 底盘（与 v1 一致的暗色板 + 投影 + 边缘光）

func drawStandardSquircleShadow(in ctx: CGContext) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 34, color: rgb(0, 0, 0, 0.36))
    ctx.setFillColor(rgb(0, 0, 0, 1))
    ctx.addPath(squirclePath)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 14, color: rgb(0, 0, 0, 0.20))
    ctx.setFillColor(rgb(0, 0, 0, 1))
    ctx.addPath(squirclePath)
    ctx.fillPath()
    ctx.restoreGState()
}

func drawSquircleRim(in ctx: CGContext) {
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()

    let rimColors = [
        rgb(1, 1, 1, 0.65),
        rgb(1, 1, 1, 0.12),
        rgb(0, 0, 0, 0.05),
        rgb(0, 0, 0, 0.30)
    ] as CFArray
    if let rimGrad = CGGradient(colorsSpace: colorSpace, colors: rimColors, locations: [0.0, 0.15, 0.85, 1.0]) {
        ctx.setLineWidth(3.0)
        ctx.addPath(squirclePath)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        ctx.drawLinearGradient(rimGrad, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    }
    ctx.restoreGState()
}

/// 暗房底盘：深空灰黑渐变 + 顶部微光
func beginDarkPlate(in ctx: CGContext, glowColor: CGColor) {
    drawStandardSquircleShadow(in: ctx)

    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()

    let bgColors = [hexColor(0x181A22), hexColor(0x101117), hexColor(0x090A0D)] as CFArray
    if let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 0.55, 1.0]) {
        ctx.drawLinearGradient(bgGrad, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    }
    let ambientGlow = [glowColor, rgb(0, 0, 0, 0.0)] as CFArray
    if let aGrad = CGGradient(colorsSpace: colorSpace, colors: ambientGlow, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(aGrad, startCenter: CGPoint(x: 512, y: 880), startRadius: 0,
                               endCenter: CGPoint(x: 512, y: 880), endRadius: 500, options: [])
    }
}

func endDarkPlate(in ctx: CGContext) {
    ctx.restoreGState() // end squircle clip
    drawSquircleRim(in: ctx)
}

// MARK: - 小件绘制

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

/// 托板（陈列架层板）：深色渐变 + 顶部高光
func drawShelfBar(in ctx: CGContext, rect: CGRect) {
    let barPath = CGPath(roundedRect: rect, cornerWidth: 12, cornerHeight: 12, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -16), blur: 24, color: rgb(0, 0, 0, 0.6))
    ctx.setFillColor(hexColor(0x191B22))
    ctx.addPath(barPath)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(barPath)
    ctx.clip()
    let barGrad = [hexColor(0x282C37), hexColor(0x191B22)] as CFArray
    if let bg = CGGradient(colorsSpace: colorSpace, colors: barGrad, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: rect.maxY), end: CGPoint(x: 512, y: rect.minY), options: [])
    }
    ctx.setStrokeColor(rgb(1, 1, 1, 0.90))
    ctx.setLineWidth(2.5)
    ctx.move(to: CGPoint(x: rect.minX + 8, y: rect.maxY - 1))
    ctx.addLine(to: CGPoint(x: rect.maxX - 8, y: rect.maxY - 1))
    ctx.strokePath()
    ctx.restoreGState()
}

// MARK: - 图标一：陈列架三类藏品（海报·蓝 / 唱片·琥珀 / 书脊·绿）

func generateShelfIcon() -> NSImage {
    let img = NSImage(size: size)
    img.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError() }
    ctx.clear(CGRect(x: 0, y: 0, width: side, height: side))

    beginDarkPlate(in: ctx, glowColor: hexColor(0x3B82F6, alpha: 0.22))

    let shelfY: CGFloat = 300          // 层板顶沿
    let itemBase = shelfY + 34         // 藏品落座于层板面

    // 藏品整体环境光晕（三色混合柔光）
    let halo = [hexColor(0x5B82F6, alpha: 0.30), rgb(0, 0, 0, 0)] as CFArray
    if let hg = CGGradient(colorsSpace: colorSpace, colors: halo, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(hg, startCenter: CGPoint(x: 512, y: 560), startRadius: 0,
                               endCenter: CGPoint(x: 512, y: 560), endRadius: 420, options: [])
    }

    // 1. 海报（影视·蓝，2:3）
    let posterRect = CGRect(x: 292, y: itemBase, width: 200, height: 300)
    let posterPath = CGPath(roundedRect: posterRect, cornerWidth: 18, cornerHeight: 18, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 30, color: hexColor(0x2B4C9A, alpha: 0.55))
    ctx.setFillColor(hexColor(0x5B82F6))
    ctx.addPath(posterPath)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(posterPath)
    ctx.clip()
    let posterGrad = [hexColor(0x7FA2FF), hexColor(0x5B82F6), hexColor(0x2B4C9A)] as CFArray
    if let pg = CGGradient(colorsSpace: colorSpace, colors: posterGrad, locations: [0.0, 0.55, 1.0]) {
        ctx.drawLinearGradient(pg, start: CGPoint(x: posterRect.minX, y: posterRect.maxY),
                               end: CGPoint(x: posterRect.maxX, y: posterRect.minY), options: [])
    }
    // 远山光影
    let wave = CGMutablePath()
    wave.move(to: CGPoint(x: posterRect.minX, y: posterRect.minY))
    wave.addLine(to: CGPoint(x: posterRect.minX, y: posterRect.minY + 95))
    wave.addCurve(to: CGPoint(x: posterRect.maxX, y: posterRect.minY + 70),
                  control1: CGPoint(x: posterRect.minX + 60, y: posterRect.minY + 60),
                  control2: CGPoint(x: posterRect.maxX - 60, y: posterRect.minY + 120))
    wave.addLine(to: CGPoint(x: posterRect.maxX, y: posterRect.minY))
    wave.closeSubpath()
    ctx.setFillColor(rgb(1, 1, 1, 0.22))
    ctx.addPath(wave)
    ctx.fillPath()
    // 顶部眩光
    let posterGlare = [rgb(1, 1, 1, 0.55), rgb(1, 1, 1, 0.0)] as CFArray
    if let gg = CGGradient(colorsSpace: colorSpace, colors: posterGlare, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(gg, start: CGPoint(x: posterRect.minX, y: posterRect.maxY),
                               end: CGPoint(x: posterRect.maxX, y: posterRect.minY), options: [])
    }
    ctx.setLineWidth(3.0)
    ctx.setStrokeColor(rgb(1, 1, 1, 0.92))
    ctx.addPath(posterPath)
    ctx.strokePath()
    ctx.restoreGState()

    // 2. 唱片（音乐·琥珀，圆形黑胶）
    let vinylCenter = CGPoint(x: 556, y: itemBase + 118)
    let vinylR: CGFloat = 118
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 30, color: hexColor(0x8A5A10, alpha: 0.55))
    ctx.setFillColor(hexColor(0x1A1208))
    ctx.addArc(center: vinylCenter, radius: vinylR, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.fillPath()
    ctx.restoreGState()

    // 盘面 + 纹槽
    ctx.setFillColor(hexColor(0xE8A33D))
    ctx.addArc(center: vinylCenter, radius: vinylR, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.fillPath()
    ctx.setStrokeColor(hexColor(0xB97A18, alpha: 0.55))
    ctx.setLineWidth(3)
    for r in stride(from: vinylR - 16, through: 52, by: -14) {
        ctx.addArc(center: vinylCenter, radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.strokePath()
    }
    // 盘芯标签 + 轴孔
    ctx.setFillColor(hexColor(0xF5C063))
    ctx.addArc(center: vinylCenter, radius: 40, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.fillPath()
    ctx.setFillColor(hexColor(0x101117))
    ctx.addArc(center: vinylCenter, radius: 10, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.fillPath()
    // 盘面高光弧
    ctx.setStrokeColor(rgb(1, 1, 1, 0.55))
    ctx.setLineWidth(6)
    ctx.setLineCap(.round)
    ctx.addArc(center: vinylCenter, radius: vinylR - 8, startAngle: .pi * 0.60, endAngle: .pi * 0.92, clockwise: false)
    ctx.strokePath()

    // 3. 书脊（书籍·绿，2:3 略小）
    let bookRect = CGRect(x: 624, y: itemBase, width: 172, height: 258)
    let bookPath = CGPath(roundedRect: bookRect, cornerWidth: 16, cornerHeight: 16, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 30, color: hexColor(0x1E6B4A, alpha: 0.55))
    ctx.setFillColor(hexColor(0x43B581))
    ctx.addPath(bookPath)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(bookPath)
    ctx.clip()
    let bookGrad = [hexColor(0x63D3A0), hexColor(0x43B581), hexColor(0x1E6B4A)] as CFArray
    if let bg2 = CGGradient(colorsSpace: colorSpace, colors: bookGrad, locations: [0.0, 0.55, 1.0]) {
        ctx.drawLinearGradient(bg2, start: CGPoint(x: bookRect.minX, y: bookRect.maxY),
                               end: CGPoint(x: bookRect.maxX, y: bookRect.minY), options: [])
    }
    // 书脊侧条 + 顶部书口
    ctx.setFillColor(rgb(0, 0, 0, 0.22))
    ctx.fill(CGRect(x: bookRect.minX, y: bookRect.minY, width: 24, height: bookRect.height))
    ctx.setFillColor(rgb(1, 1, 1, 0.35))
    ctx.fill(CGRect(x: bookRect.minX + 24, y: bookRect.maxY - 8, width: bookRect.width - 24, height: 8))
    // 顶部眩光
    let bookGlare = [rgb(1, 1, 1, 0.45), rgb(1, 1, 1, 0.0)] as CFArray
    if let bg3 = CGGradient(colorsSpace: colorSpace, colors: bookGlare, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(bg3, start: CGPoint(x: bookRect.minX, y: bookRect.maxY),
                               end: CGPoint(x: bookRect.maxX, y: bookRect.minY), options: [])
    }
    ctx.setLineWidth(3.0)
    ctx.setStrokeColor(rgb(1, 1, 1, 0.92))
    ctx.addPath(bookPath)
    ctx.strokePath()
    ctx.restoreGState()

    // 4. 层板 + 星芒
    drawShelfBar(in: ctx, rect: CGRect(x: 212, y: shelfY, width: 600, height: 34))
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 0), blur: 10, color: hexColor(0xFFE285, alpha: 0.9))
    drawSparkleStar(in: ctx, center: CGPoint(x: 512, y: shelfY + 17), radius: 15, color: hexColor(0xFFF9D6))
    ctx.restoreGState()

    endDarkPlate(in: ctx)
    img.unlockFocus()
    return img
}

// MARK: - 图标二：极简棱镜方块（品牌 conic 棱镜渐变 + 星芒）

/// 棱镜光谱五色（与 Theme.prismColors 同序），首尾相接成环
let prismSpectrum = [
    hexColor(0x5B82F6), hexColor(0x9A5BF6), hexColor(0xE85B9B),
    hexColor(0xE8A33D), hexColor(0x43B581)
]

/// 锥形（conic）渐变近似：自正上方起顺时针铺 720 个扇形楔块
/// 每块多画一格重叠量，吃掉相邻楔块抗锯齿接缝的黑线
func fillConic(in ctx: CGContext, center: CGPoint, radius: CGFloat, colors: [CGColor]) {
    let segments = 720
    let step = 2 * CGFloat.pi / CGFloat(segments)
    for i in 0..<segments {
        let a0 = CGFloat(i) * step + .pi / 2
        let a1 = a0 + step * 2   // 重叠一格，覆盖接缝
        let t = CGFloat(i) / CGFloat(segments)
        let pos = t * CGFloat(colors.count)
        let idx = Int(pos) % colors.count
        let frac = pos - floor(pos)
        let c0 = colors[idx].components ?? [0, 0, 0, 1]
        let c1 = colors[(idx + 1) % colors.count].components ?? [0, 0, 0, 1]
        let color = CGColor(srgbRed: c0[0] + (c1[0] - c0[0]) * frac,
                            green: c0[1] + (c1[1] - c0[1]) * frac,
                            blue: c0[2] + (c1[2] - c0[2]) * frac, alpha: 1)
        let wedge = CGMutablePath()
        wedge.move(to: center)
        wedge.addArc(center: center, radius: radius, startAngle: a0, endAngle: a1, clockwise: false)
        wedge.closeSubpath()
        ctx.setFillColor(color)
        ctx.addPath(wedge)
        ctx.fillPath()
    }
}

func generatePrismBlockIcon() -> NSImage {
    let img = NSImage(size: size)
    img.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError() }
    ctx.clear(CGRect(x: 0, y: 0, width: side, height: side))

    beginDarkPlate(in: ctx, glowColor: hexColor(0x9A5BF6, alpha: 0.20))

    // 棱镜方块：480×480 居中偏上
    let blockRect = CGRect(x: 272, y: 272, width: 480, height: 480)
    let blockPath = CGPath(roundedRect: blockRect, cornerWidth: 96, cornerHeight: 96, transform: nil)

    // 玻璃投影 + 棱镜色晕
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 48, color: hexColor(0x7A5BF6, alpha: 0.45))
    ctx.setFillColor(rgb(0, 0, 0, 0.8))
    ctx.addPath(blockPath)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(blockPath)
    ctx.clip()

    // conic 棱镜光谱
    fillConic(in: ctx, center: CGPoint(x: 512, y: 512), radius: 480, colors: prismSpectrum)

    // 斜向玻璃眩光（克制，保住光谱饱和度）
    let glare = [
        rgb(1, 1, 1, 0.34),
        rgb(1, 1, 1, 0.10),
        rgb(1, 1, 1, 0.0),
        rgb(1, 1, 1, 0.08)
    ] as CFArray
    if let gl = CGGradient(colorsSpace: colorSpace, colors: glare, locations: [0.0, 0.35, 0.65, 1.0]) {
        ctx.drawLinearGradient(gl, start: CGPoint(x: blockRect.minX, y: blockRect.maxY),
                               end: CGPoint(x: blockRect.maxX, y: blockRect.minY), options: [])
    }

    // 内部远山光影（与画架版一致的家族细节）
    let wave = CGMutablePath()
    wave.move(to: CGPoint(x: blockRect.minX, y: blockRect.minY))
    wave.addLine(to: CGPoint(x: blockRect.minX, y: blockRect.minY + 130))
    wave.addCurve(to: CGPoint(x: blockRect.midX + 40, y: blockRect.minY + 155),
                  control1: CGPoint(x: blockRect.minX + 80, y: blockRect.minY + 95),
                  control2: CGPoint(x: blockRect.midX - 40, y: blockRect.minY + 185))
    wave.addCurve(to: CGPoint(x: blockRect.maxX, y: blockRect.minY + 105),
                  control1: CGPoint(x: blockRect.midX + 110, y: blockRect.minY + 125),
                  control2: CGPoint(x: blockRect.maxX - 60, y: blockRect.minY + 150))
    wave.addLine(to: CGPoint(x: blockRect.maxX, y: blockRect.minY))
    wave.closeSubpath()
    ctx.setFillColor(rgb(1, 1, 1, 0.12))
    ctx.addPath(wave)
    ctx.fillPath()

    ctx.setLineWidth(3.0)
    ctx.setStrokeColor(rgb(1, 1, 1, 0.92))
    ctx.addPath(blockPath)
    ctx.strokePath()
    ctx.restoreGState()

    // 右上角星芒点睛
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 0), blur: 14, color: hexColor(0xFFE285, alpha: 0.9))
    drawSparkleStar(in: ctx, center: CGPoint(x: 742, y: 752), radius: 34, color: hexColor(0xFFF9D6))
    ctx.restoreGState()
    drawSparkleStar(in: ctx, center: CGPoint(x: 700, y: 800), radius: 14, color: rgb(1, 1, 1, 0.95))

    endDarkPlate(in: ctx)
    img.unlockFocus()
    return img
}

// MARK: - 输出

func saveImage(_ image: NSImage, to path: String) {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Failed to encode PNG for \(path)")
    }
    try! png.write(to: URL(fileURLWithPath: path), options: .atomic)
    print("Saved: \(path)")
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "ArtShelf/Resources/Icons"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

saveImage(generateShelfIcon(), to: "\(outDir)/shelf_dark.png")
saveImage(generatePrismBlockIcon(), to: "\(outDir)/prism_block.png")

print("v2 icons generated successfully into \(outDir)!")
