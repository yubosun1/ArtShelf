import AppKit
import CoreGraphics

extension NSImage {

    /// 封面主色（活力主题色，供光晕与环境渲染使用）
    ///
    /// 相比朴素的整图均值（CIAreaAverage 会被大面积黑色背景或白字拉成死灰/浑浊色），
    /// 该算法在降采样像素图上过滤过暗、过亮与过低饱和度像素，
    /// 按色相环进行直方图桶聚类并根据色彩饱和度加权，
    /// 提取出最具表现力的封面主题色，并适度做饱和度提升，确保暗房光晕鲜活通透。
    func dominantColor() -> NSColor? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let targetSize = 64
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: targetSize * targetSize * 4)
        guard let context = CGContext(
            data: &rawData,
            width: targetSize,
            height: targetSize,
            bitsPerComponent: 8,
            bytesPerRow: targetSize * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetSize, height: targetSize))

        // 24 个色相区间桶（每桶 15 度）
        var hueBuckets = [Double](repeating: 0, count: 24)
        var bucketColors = [(r: Double, g: Double, b: Double)](repeating: (0, 0, 0), count: 24)
        var totalWeighted: Double = 0
        var fallbackR: Double = 0, fallbackG: Double = 0, fallbackB: Double = 0
        var sampleCount = 0

        let pixelCount = targetSize * targetSize
        for i in 0..<pixelCount {
            let r = Double(rawData[i * 4]) / 255.0
            let g = Double(rawData[i * 4 + 1]) / 255.0
            let b = Double(rawData[i * 4 + 2]) / 255.0
            let a = Double(rawData[i * 4 + 3]) / 255.0
            guard a > 0.5 else { continue }

            sampleCount += 1
            fallbackR += r
            fallbackG += g
            fallbackB += b

            let maxVal = max(r, max(g, b))
            let minVal = min(r, min(g, b))
            let delta = maxVal - minVal
            let brightness = maxVal
            let saturation = maxVal == 0 ? 0 : delta / maxVal

            // 过滤极暗背景（B < 0.15）、极亮纯白/浅灰文字（B > 0.92 且 S < 0.15）以及接近无色的死灰（S < 0.12）
            if brightness < 0.15 || (brightness > 0.92 && saturation < 0.15) || saturation < 0.12 {
                continue
            }

            var hue: Double = 0
            if delta != 0 {
                if maxVal == r {
                    hue = (g - b) / delta + (g < b ? 6 : 0)
                } else if maxVal == g {
                    hue = (b - r) / delta + 2
                } else {
                    hue = (r - g) / delta + 4
                }
                hue /= 6.0
            }

            let bucket = Int(hue * 24.0) % 24
            // 以饱和度平方加权，同时抑制极端亮度，让鲜明且舒适的主题色脱颖而出
            let weight = saturation * saturation * (1.0 - abs(brightness - 0.5) * 0.6)
            hueBuckets[bucket] += weight
            totalWeighted += weight
            bucketColors[bucket].r += r * weight
            bucketColors[bucket].g += g * weight
            bucketColors[bucket].b += b * weight
        }

        if totalWeighted > 0,
           let bestBucket = hueBuckets.indices.max(by: { hueBuckets[$0] < hueBuckets[$1] }),
           hueBuckets[bestBucket] > 0 {
            let sumWeight = hueBuckets[bestBucket]
            let r = bucketColors[bestBucket].r / sumWeight
            let g = bucketColors[bestBucket].g / sumWeight
            let b = bucketColors[bestBucket].b / sumWeight

            let candidate = NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
            var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 0
            candidate.getHue(&h, saturation: &s, brightness: &br, alpha: &a)

            // 为暗房环境光适当增益饱和度与亮度下限，使暗调界面充满戏剧感呼吸感
            let boostedS = min(1.0, max(0.52, s * 1.3))
            let boostedB = min(0.92, max(0.48, br))
            return NSColor(hue: h, saturation: boostedS, brightness: boostedB, alpha: 1.0)
        }

        // 全图为纯黑白/灰度时的兜底均值
        guard sampleCount > 0 else { return nil }
        return NSColor(
            srgbRed: fallbackR / Double(sampleCount),
            green: fallbackG / Double(sampleCount),
            blue: fallbackB / Double(sampleCount),
            alpha: 1.0
        )
    }
}

