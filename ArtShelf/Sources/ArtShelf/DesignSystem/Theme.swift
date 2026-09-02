import SwiftUI
import AppKit

/// v3 设计令牌 ——「沉浸暗房」完整主题设计系统
///
/// 令牌口径与 `docs/product-design.md` §5.1 一一对应。
/// 完整主题（跟随系统 / 白昼放映厅 / 暗房 / 午夜蓝场 / 羊皮纸）转发到
/// `ThemeSettings.shared.theme` 的整套调色板；强调色（amber 系列）转发到
/// `ThemeSettings.shared.accent` 的主题色套件，均随设置切换实时刷新。
enum Theme {

    // MARK: - 调色板（语义令牌，转发当前完整主题）

    /// 窗口主画布
    static var bg: Color { ThemeSettings.shared.theme.palette.bg }
    /// 标题栏
    static var titlebar: Color { ThemeSettings.shared.theme.palette.titlebar }
    /// 卡片 / 浮层
    static var panel: Color { ThemeSettings.shared.theme.palette.panel }

    /// 一级文字
    static var ink: Color { ThemeSettings.shared.theme.palette.ink }
    /// 次级文字
    static var ink2: Color { ThemeSettings.shared.theme.palette.ink2 }
    /// 三级文字
    static var ink3: Color { ThemeSettings.shared.theme.palette.ink3 }

    /// 发丝分隔线
    static var rule: Color { ThemeSettings.shared.theme.palette.rule }
    /// 内凹槽（搜索框 / 按钮底）
    static var well: Color { ThemeSettings.shared.theme.palette.well }
    /// 进度条轨道
    static var track: Color { ThemeSettings.shared.theme.palette.track }

    /// 主题强调色（文字 / 进度 / 点睛；随设置的主题色套件切换，默认琥珀）
    static var amber: Color { ThemeSettings.shared.accent.accent }
    /// 主按钮底色（深浅一致）
    static var amberBtn: Color { ThemeSettings.shared.accent.button }
    /// 主按钮上的文字色
    static var amberOn: Color { ThemeSettings.shared.accent.buttonOn }
    /// 强调渐亮端（进度条渐变）
    static var amberHi: Color { ThemeSettings.shared.accent.highlight }

    // MARK: - 状态徽标配色（底 / 字）

    static let doneBg = dynamic(light: hex(0x2B9664, alpha: 0.13), dark: hex(0x43B581, alpha: 0.25))
    static let doneTx = dynamic(light: hex(0x2E8F63), dark: hex(0x7FE0B2))
    static var doingBg: Color { ThemeSettings.shared.accent.doingBg }
    static var doingTx: Color { ThemeSettings.shared.accent.doingTx }
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

    static func dynamic(light: Color, dark: Color) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let darkMode = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return darkMode ? NSColor(dark) : NSColor(light)
        })
    }

    static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let darkMode = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return darkMode ? dark : light
        })
    }

    static func hex(_ value: UInt32, alpha: CGFloat = 1) -> NSColor {
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
