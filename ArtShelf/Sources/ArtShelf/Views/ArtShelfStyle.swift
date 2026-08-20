import SwiftUI
import AppKit

/// ArtShelf 的设计层——书房纸面，编辑排版。
///
/// 所有颜色、圆角、间距、字号都在这里定义，视图只引用不自造。
/// 审美取向：像一页书或画廊目录——标题用宋体，分隔用发丝线，
/// 不用圆角卡片和彩色胶囊堆砌；朱砂红像印章一样，只在评分、
/// 选中、关键操作上落一点。
enum ArtShelfStyle {

    // MARK: - 调色板

    /// 窗口画布：象牙纸
    static let paper = dynamic(
        light: hex(0xF7F4EC),
        dark:  hex(0x181715)
    )

    /// 抬起一层的表面：侧栏、工具条
    static let surface = dynamic(
        light: hex(0xEFEBE1),
        dark:  hex(0x201F1C)
    )

    /// 再抬一层：输入框、填充控件
    static let well = dynamic(
        light: hex(0xE7E1D3),
        dark:  hex(0x2B2925)
    )

    /// 正文墨色
    static let ink = dynamic(
        light: hex(0x221F1B),
        dark:  hex(0xEAE5D9)
    )

    /// 次级文字
    static let inkSecondary = dynamic(
        light: hex(0x221F1B, alpha: 0.62),
        dark:  hex(0xEAE5D9, alpha: 0.60)
    )

    /// 三级文字：提示、占位、计数
    static let inkTertiary = dynamic(
        light: hex(0x221F1B, alpha: 0.40),
        dark:  hex(0xEAE5D9, alpha: 0.38)
    )

    /// 朱砂红——像印章，少落，落准
    static let accent = dynamic(
        light: hex(0xA93B27),
        dark:  hex(0xDC7250)
    )

    /// 强调色的浅底，用于选中态背景
    static let accentWash = dynamic(
        light: hex(0xA93B27, alpha: 0.09),
        dark:  hex(0xDC7250, alpha: 0.14)
    )

    /// 发丝分隔线
    static let rule = dynamic(
        light: hex(0x221F1B, alpha: 0.09),
        dark:  hex(0xEAE5D9, alpha: 0.12)
    )

    /// 书架横木：托住每一排封面（ledge 渐变的中间色，单独使用时的兜底色）
    static let shelf = dynamic(
        light: hex(0x9C8464, alpha: 0.55),
        dark:  hex(0x7D6A4F, alpha: 0.55)
    )

    /// 木架沿的受光面与背光面——ShelfLedge 用它们拉出一点体积感
    static let shelfHi = dynamic(
        light: hex(0xC4AA80),
        dark:  hex(0x8A765A)
    )
    static let shelfLo = dynamic(
        light: hex(0x937D5C),
        dark:  hex(0x63543F)
    )

    /// 悬停时的轻微提亮
    static let hoverFill = dynamic(
        light: hex(0x221F1B, alpha: 0.04),
        dark:  hex(0xEAE5D9, alpha: 0.05)
    )

    static let coverShadow = Color.black.opacity(0.12)

    // MARK: - 尺寸

    static let cardWidth: CGFloat = 164
    /// 封面井的高度 = 最高的封面（2:3 海报）。方形专辑底部对齐，一起落在书架线上。
    static let coverWellHeight: CGFloat = cardWidth * 1.5

    /// 封面只留一点圆角，像裁切整齐的印刷品
    static let cardRadius: CGFloat = 3
    static let controlRadius: CGFloat = 5
    static let panelRadius: CGFloat = 8

    static let contentPadding: CGFloat = 30
    static let gridSpacing: CGFloat = 26
    static let rowSpacing: CGFloat = 32

    // MARK: - 字体

    /// 标题字：宋体。藏书与画廊目录的人文感主要来自它。
    static func serifTitle(_ size: CGFloat = 15, weight: Font.Weight = .semibold) -> Font {
        serifFont(size: size, weight: weight)
    }

    /// 页眉大标题：目录页/详情页的章节题
    static let pageTitle = serifFont(size: 28, weight: .semibold)

    /// 副题/署名行：紧随大标题的一行小字
    static let byline = serifFont(size: 13, weight: .regular)

    /// 衬线正文：用于简介等值得慢读的段落
    static func serifBody(_ size: CGFloat = 13) -> Font {
        serifFont(size: size, weight: .regular)
    }

    /// 旧接口保留——现在同样返回宋体标题
    static func title(_ size: CGFloat = 15) -> Font {
        serifTitle(size)
    }

    static let cardTitle = serifFont(size: 13, weight: .medium)
    static let cardMeta = Font.system(size: 10.5, weight: .regular)
    static let body = Font.system(size: 12.5)
    static let control = Font.system(size: 12, weight: .medium)

    /// 优先使用系统自带的宋体（Songti SC），缺失时退到系统衬线体
    private static func serifFont(size: CGFloat, weight: Font.Weight) -> Font {
        if NSFont(name: "Songti SC", size: size) != nil {
            return .custom("Songti SC", size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .serif)
    }

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

/// 目录式的小节题：宋体、加宽字距，像书页上的栏目名
struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(ArtShelfStyle.serifTitle(10.5, weight: .medium))
            .tracking(2)
            .foregroundStyle(ArtShelfStyle.inkTertiary)
    }
}

// MARK: - 纸面横线

/// 比 `Divider` 更轻、颜色统一的发丝线。
struct PaperRule: View {
    var body: some View {
        ArtShelfStyle.rule
            .frame(height: 1)
    }
}

// MARK: - 朱砂小方印

/// 页眉标题前的一点朱砂，像钤在纸上的印章——全场唯一允许的装饰。
struct SealMark: View {
    var size: CGFloat = 7

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(ArtShelfStyle.accent)
            .frame(width: size, height: size)
    }
}

// MARK: - 书架木沿

/// 托住封面的木架沿：受光面到背光面的细微渐变，下方落一点影子，
/// 让一排封面看起来像真的立在木头上。
struct ShelfLedge: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [ArtShelfStyle.shelfHi, ArtShelfStyle.shelfLo],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: 3)
            .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1.5)
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
