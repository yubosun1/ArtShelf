import AppKit

// ArtShelf 应用图标：三个色块立在一道搁板上。
//
// 有意不画胶片孔、唱片纹、书页——那些细节在 Dock 的 32pt 下会糊成一团。
// 只保留"三样东西，一个架子"这一个可读的记号：不同高度、不同明度的三块，
// 加一道托住它们的横木。米白纸底 + 珊瑚红，和界面同一套调色板。

let outputPath = CommandLine.arguments.dropFirst().first ?? "Resources/icon_final_v2.png"
let side: CGFloat = 1024
let image = NSImage(size: NSSize(width: side, height: side))

image.lockFocus()
guard let context = NSGraphicsContext.current else {
    fatalError("Unable to create graphics context")
}
context.imageInterpolation = .high

NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: side, height: side).fill()

// macOS 图标网格：内容占据画布中央约 82%，四周留出投影空间。
let plate = NSRect(x: 92, y: 92, width: 840, height: 840)
let plateRadius: CGFloat = 188
let platePath = NSBezierPath(roundedRect: plate, xRadius: plateRadius, yRadius: plateRadius)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green:   CGFloat((hex >> 8) & 0xFF) / 255,
        blue:    CGFloat(hex & 0xFF) / 255,
        alpha:   alpha
    )
}

let paperTop    = color(0xFDFAF4)
let paperBottom = color(0xF0E7D6)
let coral       = color(0xC8492F)
let coralLight  = color(0xD9694F)
let ink         = color(0x2A2621)
let shelfWood   = color(0x8C7350)

// 投影
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.26)
shadow.shadowBlurRadius = 30
shadow.shadowOffset = NSSize(width: 0, height: -14)
shadow.set()
NSColor.white.setFill()
platePath.fill()
NSGraphicsContext.restoreGraphicsState()

// 纸底：极轻的竖向渐变，让平面不死板
NSGraphicsContext.saveGraphicsState()
platePath.addClip()
NSGradient(starting: paperTop, ending: paperBottom)?
    .draw(in: plate, angle: -90)
NSGraphicsContext.restoreGraphicsState()

func roundedRect(_ rect: NSRect, radius: CGFloat, fill: NSColor) {
    fill.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

// 三块书脊：宽度一致、间距一致，高度中间最高向两侧递落。
// 中间那块用珊瑚红成为视觉落点，两侧墨色——明度差保证 32pt 下仍分得开。
let blockWidth: CGFloat = 138
let gap: CGFloat = 30
let totalWidth = blockWidth * 3 + gap * 2
let startX = (side - totalWidth) / 2

// 搁板顶面就是三块的基线，两端各出挑一点，读起来是"架子"而不是"下划线"。
let shelfTop: CGFloat = 322
let shelfThickness: CGFloat = 40
let overhang: CGFloat = 28

let heights: [CGFloat] = [318, 408, 268]
let fills: [NSColor] = [ink, coral, ink]

for index in 0..<3 {
    let x = startX + CGFloat(index) * (blockWidth + gap)
    // 底边探进搁板 16pt，随后画的搁板会盖住它——这样接缝处没有圆角留下的缝隙。
    let rect = NSRect(x: x, y: shelfTop - 16, width: blockWidth, height: heights[index] + 16)
    roundedRect(rect, radius: 26, fill: fills[index])
}

// 搁板画在书脊之后、坐标更低，因此书脊底边被它干净地截断，形成"立在架上"。
let shelfRect = NSRect(
    x: startX - overhang,
    y: shelfTop - shelfThickness,
    width: totalWidth + overhang * 2,
    height: shelfThickness
)
roundedRect(shelfRect, radius: 14, fill: shelfWood)

// 中间书脊上的一道浅色标签，暗示书名——大尺寸可见，小尺寸自然并入色块。
let label = NSRect(
    x: startX + blockWidth + gap + 24,
    y: shelfTop + heights[1] - 96,
    width: blockWidth - 48,
    height: 13
)
roundedRect(label, radius: 6.5, fill: coralLight)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode icon")
}

try png.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
