// GeneratedCoverView.swift —— 无封面时的生成式封面
// 概念稿的封面装饰手法：按标题稳定取色的三色渐变 + 顶部微光 + 底部压暗 + 左下排版。
// 同一标题永远得到同一配色；仅在视图足够大时显示文字（队列小图只留渐变）。
import SwiftUI

struct GeneratedCoverView: View {

    let title: String
    let creator: String?
    let year: String?        // 形如「王家卫 · 2000」的组合串
    var cornerRadius: CGFloat = 0
    /// 是否显示左下排版（Hero 环境色虚化等场景需要无字封面）
    var showsText: Bool = true

    /// 封面主色（供光晕 / 环境渲染取色）
    var dominantColor: Color { colors[1] }

    /// 配色库：取自概念稿封面渐变（均为深调，浅色文字）
    private static let palette: [(UInt32, UInt32, UInt32)] = [
        (0x7E1F2E, 0x471120, 0x1E2B22),  // 暗红
        (0x101726, 0x1D2C4C, 0x0A0D16),  // 藏蓝
        (0x1F6E6B, 0x0F3D3E, 0x123030),  // 青碧
        (0xB98A1C, 0x8C1F1F, 0x1B1B1B),  // 金红
        (0x232323, 0x2B2419, 0x0C0C0C),  // 黑金
        (0x5E7C99, 0x33465C, 0x1B2530),  // 钢蓝
        (0xC97E3F, 0xA8542F, 0x5E2A1C),  // 暖橙
        (0xB98A34, 0x9E5E28, 0x5E2F16),  // 琥珀
        (0x9E2620, 0x5E130F, 0x1F0B09),  // 深红
        (0x3E6B4F, 0x24402F, 0x122019),  // 墨绿
        (0xA85E7B, 0x6E3B62, 0x2A1A2E),  // 粉紫
        (0x2E2E33, 0x17171B, 0x0D0D10),  // 石墨
    ]

    /// 稳定哈希（djb2）：String.hashValue 每次运行随机，不可用
    private var paletteIndex: Int {
        var hash: UInt64 = 5381
        for scalar in title.unicodeScalars {
            hash = (hash &* 33) &+ UInt64(scalar.value)
        }
        return Int(hash % UInt64(Self.palette.count))
    }

    private var colors: [Color] {
        let (top, mid, bottom) = Self.palette[paletteIndex]
        return [Self.rgb(top), Self.rgb(mid), Self.rgb(bottom)]
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                // 主渐变（160°，近似 topLeading → bottomTrailing）
                LinearGradient(colors: colors,
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                // 顶部微光
                RadialGradient(colors: [Color.white.opacity(0.22), .clear],
                               center: .init(x: 0.78, y: 0.12),
                               startRadius: 8, endRadius: geo.size.width * 1.1)
                // 底部压暗（承托文字）
                LinearGradient(colors: [Color.black.opacity(0.42), .clear],
                               startPoint: .bottom, endPoint: .center)

                // 左下排版：视图够大才显示
                if showsText, geo.size.width >= 110 {
                    VStack(alignment: .leading, spacing: geo.size.width * 0.02) {
                        Text(title)
                            .font(.system(size: geo.size.width * 0.082, weight: .semibold))
                            .tracking(geo.size.width * 0.006)
                        if let year {
                            Text(year)
                                .font(.system(size: geo.size.width * 0.054))
                                .tracking(geo.size.width * 0.011)
                                .opacity(0.72)
                        }
                    }
                    .foregroundStyle(Color.white.opacity(0.93))
                    .shadow(color: Color.black.opacity(0.35), radius: 2, y: 1)
                    .padding(.leading, geo.size.width * 0.07)
                    .padding(.bottom, geo.size.width * 0.063)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private static func rgb(_ value: UInt32, alpha: Double = 1) -> Color {
        Color(.sRGB,
              red: Double((value >> 16) & 0xFF) / 255,
              green: Double((value >> 8) & 0xFF) / 255,
              blue: Double(value & 0xFF) / 255,
              opacity: alpha)
    }
}
