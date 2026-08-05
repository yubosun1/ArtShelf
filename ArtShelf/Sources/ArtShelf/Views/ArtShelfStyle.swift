import SwiftUI
import AppKit

/// ArtShelf 的设计层——纸质暖调。
///
/// 所有颜色、圆角、间距、字号都在这里定义，视图只引用不自造。
/// 颜色一律用动态 NSColor，浅色是米白纸张，深色是暖褐夜纸，
/// 珊瑚红只在需要指向性的地方出现（选中、强调、评分）。
enum ArtShelfStyle {

    // MARK: - 调色板

    /// 窗口画布：纸张本身
    static let paper = dynamic(
        light: hex(0xFAF6EF),
        dark:  hex(0x1A1817)
    )

    /// 抬起一层的表面：侧栏、工具条、卡片悬停
    static let surface = dynamic(
        light: hex(0xF2ECE1),
        dark:  hex(0x232120)
    )

    /// 再抬一层：输入框、胶囊、填充控件
    static let well = dynamic(
        light: hex(0xE9E2D5),
        dark:  hex(0x2C2A28)
    )

    /// 正文墨色
    static let ink = dynamic(
        light: hex(0x24211D),
        dark:  hex(0xECE6DC)
    )

    /// 次级文字
    static let inkSecondary = dynamic(
        light: hex(0x24211D, alpha: 0.62),
        dark:  hex(0xECE6DC, alpha: 0.60)
    )

    /// 三级文字：提示、占位、计数
    static let inkTertiary = dynamic(
        light: hex(0x24211D, alpha: 0.38),
        dark:  hex(0xECE6DC, alpha: 0.36)
    )

    /// 珊瑚红强调色
    static let accent = dynamic(
        light: hex(0xC8492F),
        dark:  hex(0xE4694E)
    )

    /// 强调色的浅底，用于选中态背景
    static let accentWash = dynamic(
        light: hex(0xC8492F, alpha: 0.10),
        dark:  hex(0xE4694E, alpha: 0.16)
    )

    /// 分隔线
    static let rule = dynamic(
        light: hex(0x24211D, alpha: 0.10),
        dark:  hex(0xECE6DC, alpha: 0.11)
    )

    /// 书架横木：托住每一排封面
    static let shelf = dynamic(
        light: hex(0xB29A78, alpha: 0.55),
        dark:  hex(0x8A7355, alpha: 0.55)
    )

    /// 悬停时的轻微提亮
    static let hoverFill = dynamic(
        light: hex(0x24211D, alpha: 0.045),
        dark:  hex(0xECE6DC, alpha: 0.055)
    )

    static let coverShadow = Color.black.opacity(0.16)

    // MARK: - 尺寸

    static let cardWidth: CGFloat = 168
    /// 封面井的高度 = 最高的封面（2:3 海报）。方形专辑底部对齐，一起落在书架线上。
    static let coverWellHeight: CGFloat = cardWidth * 1.5

    static let cardRadius: CGFloat = 6
    static let controlRadius: CGFloat = 7
    static let panelRadius: CGFloat = 10

    static let contentPadding: CGFloat = 28
    static let gridSpacing: CGFloat = 22
    static let rowSpacing: CGFloat = 26

    // MARK: - 字体

    static func title(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    static let cardTitle = Font.system(size: 12.5, weight: .medium)
    static let cardMeta = Font.system(size: 10.5, weight: .regular)
    static let body = Font.system(size: 12.5)
    static let control = Font.system(size: 12, weight: .medium)

    // MARK: - 动态颜色构造

    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return isDark ? dark : light
        })
    }

    private static func hex(_ value: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green:   CGFloat((value >> 8) & 0xFF) / 255,
            blue:    CGFloat(value & 0xFF) / 255,
            alpha:   alpha
        )
    }
}

// MARK: - 小节标题

struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 9.5, weight: .semibold))
            .tracking(0.9)
            .foregroundStyle(ArtShelfStyle.inkTertiary)
    }
}

// MARK: - 纸面横线

/// 比 `Divider` 更轻、颜色统一的分隔线。
struct PaperRule: View {
    var body: some View {
        ArtShelfStyle.rule
            .frame(height: 1)
    }
}

// MARK: - 复用修饰符

extension View {
    /// 填充式控件底（输入框、胶囊按钮）
    func wellBackground(radius: CGFloat = ArtShelfStyle.controlRadius) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(ArtShelfStyle.well)
        )
    }

    /// 面板底：比画布抬起一层，带极细描边
    func panelBackground(radius: CGFloat = ArtShelfStyle.panelRadius) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(ArtShelfStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(ArtShelfStyle.rule, lineWidth: 1)
        )
    }
}
