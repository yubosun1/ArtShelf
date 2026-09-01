import SwiftUI
import AppKit

/// v3 设计令牌 ——「沉浸暗房」深浅双色设计系统
///
/// 令牌口径与 `docs/product-design.md` §5.1 一一对应。
/// 深色为「暗房」，浅色为「白昼放映厅」（暖纸调）；
/// 一律跟随系统外观，不提供手动切换。
enum Theme {

    // MARK: - 调色板（语义令牌）

    /// 窗口主画布
    static let bg = dynamic(light: hex(0xF5F4F0), dark: hex(0x0D0E11))
    /// 标题栏
    static let titlebar = dynamic(light: hex(0xECEAE3), dark: hex(0x101116))
    /// 卡片 / 浮层
    static let panel = dynamic(light: hex(0xFFFFFF), dark: hex(0x17191F))

    /// 一级文字
    static let ink = dynamic(light: hex(0x1B1D23), dark: hex(0xF2F3F6))
    /// 次级文字
    static let ink2 = dynamic(light: hex(0x5A5F6B), dark: hex(0xA6ABB8))
    /// 三级文字
    static let ink3 = dynamic(light: hex(0x9AA0AC), dark: hex(0x6B7180))

    /// 发丝分隔线
    static let rule = dynamic(light: Color.black.opacity(0.09), dark: Color.white.opacity(0.07))
    /// 内凹槽（搜索框 / 按钮底）
    static let well = dynamic(light: Color.black.opacity(0.055), dark: Color.white.opacity(0.07))
    /// 进度条轨道
    static let track = dynamic(light: Color.black.opacity(0.12), dark: Color.white.opacity(0.12))

    /// 强调色（文字 / 进度 / 点睛）
    static let amber = dynamic(light: hex(0xC07A14), dark: hex(0xE8A33D))
    /// 主按钮底色（深浅一致）
    static let amberBtn = Color(nsColor: hex(0xE8A33D))
    /// 主按钮上的文字色
    static let amberOn = dynamic(light: hex(0x2A1B06), dark: hex(0x1A1208))
    /// 琥珀渐亮端（进度条渐变）
    static let amberHi = Color(nsColor: hex(0xF5C063))

    // MARK: - 状态徽标配色（底 / 字）

    static let doneBg = dynamic(light: hex(0x2B9664, alpha: 0.13), dark: hex(0x43B581, alpha: 0.25))
    static let doneTx = dynamic(light: hex(0x2E8F63), dark: hex(0x7FE0B2))
    static let doingBg = dynamic(light: hex(0xC8820F, alpha: 0.15), dark: hex(0xE8A33D, alpha: 0.28))
    static let doingTx = dynamic(light: hex(0xAE6F0F), dark: hex(0xF5C063))
    static let todoBg = dynamic(light: hex(0x6E788C, alpha: 0.14), dark: hex(0x77809A, alpha: 0.30))
    static let todoTx = dynamic(light: hex(0x6A7386), dark: hex(0xB9C0D4))

    /// 状态徽标配色对
    static func statusColors(_ status: MediaStatus) -> (bg: Color, tx: Color) {
        switch status {
        case .completed:  return (doneBg, doneTx)
        case .inProgress: return (doingBg, doingTx)
        case .planned:    return (todoBg, todoTx)
        }
    }

    // MARK: - 品牌棱镜与类型代表色

    /// 品牌棱镜渐变六色（顶栏 / 设置 Logo，与概念稿 conic-gradient 一致）
    static let prismColors: [Color] = [
        Color(nsColor: hex(0x5B82F6)),
        Color(nsColor: hex(0x9A5BF6)),
        Color(nsColor: hex(0xE85B9B)),
        Color(nsColor: hex(0xE8A33D)),
        Color(nsColor: hex(0x43B581)),
        Color(nsColor: hex(0x5B82F6))
    ]

    /// 类型代表色（概念稿调色板，深浅一致）：影视蓝 / 音乐琥珀 / 书籍绿
    static let typeMovie = Color(nsColor: hex(0x5B82F6))
    static let typeMusic = Color(nsColor: hex(0xE8A33D))
    static let typeBook = Color(nsColor: hex(0x43B581))

    // MARK: - 光效强度（随外观变化的标量）

    /// 封面主色光晕透明度
    static func glowAlpha(_ scheme: ColorScheme) -> Double { scheme == .dark ? 0.42 : 0.20 }
    /// 封面投影强度
    static func shadowAlpha(_ scheme: ColorScheme) -> Double { scheme == .dark ? 0.50 : 0.16 }
    /// Hero 环境渲染不透明度
    static func ambientOpacity(_ scheme: ColorScheme) -> Double { scheme == .dark ? 1.0 : 0.5 }

    // MARK: - 结构尺寸（§5.4）

    static let contentPadding: CGFloat = 40
    static let sectionSpacing: CGFloat = 34
    static let rowSpacing: CGFloat = 20

    /// 卡片封面（影视 / 书籍 2:3 → 158×237；音乐方形 1:1 → 158×158）
    static let cardWidth: CGFloat = 158
    static let cardPosterHeight: CGFloat = 237
    static let cardSquareSide: CGFloat = 158

    /// Hero 大封面 236×354
    static let heroCoverSize = CGSize(width: 236, height: 354)
    /// 队列迷你封面 40×56（音乐方形 40×40）
    static let queueCoverWidth: CGFloat = 40
    static let queueCoverHeight: CGFloat = 56

    static let cardCorner: CGFloat = 8
    static let panelCorner: CGFloat = 12

    /// 卡片封面尺寸（按类型宽高比取 2:3 / 1:1）
    static func cardCoverSize(for type: MediaType) -> CGSize {
        type.coverAspectRatio == 1
            ? CGSize(width: cardWidth, height: cardSquareSide)
            : CGSize(width: cardWidth, height: cardPosterHeight)
    }

    /// 队列迷你封面尺寸（2:3 → 40×56，方形 → 40×40）
    static func queueCoverSize(for type: MediaType) -> CGSize {
        type.coverAspectRatio == 1
            ? CGSize(width: queueCoverWidth, height: queueCoverWidth)
            : CGSize(width: queueCoverWidth, height: queueCoverHeight)
    }

    // MARK: - 字体层次

    static let heroTitle = Font.system(size: 44, weight: .heavy)
    static let sectionTitle = Font.system(size: 19, weight: .heavy)
    static let cardTitle = Font.system(size: 12.5, weight: .semibold)
    static let cardMeta = Font.system(size: 10.5)
    static let body = Font.system(size: 13)
    static let control = Font.system(size: 12, weight: .medium)
    static let kicker = Font.system(size: 11, weight: .bold)

    // MARK: - 动态颜色构造

    private static func dynamic(light: Color, dark: Color) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let darkMode = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return darkMode ? NSColor(dark) : NSColor(light)
        })
    }

    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let darkMode = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return darkMode ? dark : light
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

// MARK: - 通用修饰符

extension View {
    /// 卡片悬停微浮起（上浮 + 呼吸感微放大）
    func cardHoverLift(_ isHovered: Bool) -> some View {
        self
            .offset(y: isHovered ? -6 : 0)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.76), value: isHovered)
    }

    /// 封面主色光晕：以封面主色投下大面积色晕，强度随外观
    /// 半径口径对齐概念稿（0 18px 44px 主色晕 + 0 6px 14px 黑投影）
    func coverGlow(_ color: Color?, scheme: ColorScheme, radius: CGFloat = 44) -> some View {
        let alpha = Theme.glowAlpha(scheme)
        return self
            .shadow(
                color: (color ?? Theme.amberBtn).opacity(alpha),
                radius: radius, x: 0, y: 18
            )
            .shadow(
                color: (color ?? Theme.amberBtn).opacity(alpha * 0.5),
                radius: radius * 0.45, x: 0, y: 8
            )
            .shadow(color: .black.opacity(Theme.shadowAlpha(scheme)), radius: 14, x: 0, y: 6)
    }
}
