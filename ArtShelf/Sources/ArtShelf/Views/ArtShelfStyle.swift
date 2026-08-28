import SwiftUI
import AppKit

/// ArtShelf 现代画廊设计系统 (Modern Media Atelier)
///
/// 遵循 Apple macOS 人机交互指南 (HIG)，以“媒体封面即主角”为核心理念：
/// - 画布采用通透纯净的高级中性基调，衬托电影海报、黑胶专辑与书籍装帧的丰富色彩；
/// - 采用柔和环境光感（Ambient Shadows）与微浮动反馈（Lift Elevation）；
/// - 优雅现代的排版，高对比度易读性，原生毛玻璃与精细微描边。
enum ArtShelfStyle {

    // MARK: - 调色板

    /// 窗口主画布背景：浅色纯净通透灰白，深色沉浸式深空炭灰
    static let paper = dynamic(
        light: hex(0xF9FAFB),
        dark:  hex(0x131417)
    )

    /// 抬起一层的表面：侧栏底色、卡片、浮动面板
    static let surface = dynamic(
        light: hex(0xFFFFFF),
        dark:  hex(0x1B1C22)
    )

    /// 侧栏专属背景（更贴合 macOS 系统侧栏质感）
    static let sidebarBackground = dynamic(
        light: hex(0xF4F5F7),
        dark:  hex(0x17181D)
    )

    /// 填充控件与内凹槽（搜索框、标签背景、输入框）
    static let well = dynamic(
        light: hex(0xEEF1F4),
        dark:  hex(0x23252D)
    )

    /// 控件悬停底色
    static let wellHover = dynamic(
        light: hex(0xE4E7EB),
        dark:  hex(0x2A2D37)
    )

    /// 一级主文字（高对比度，清晰有力）
    static let ink = dynamic(
        light: hex(0x121316),
        dark:  hex(0xF4F5F7)
    )

    /// 次级文字（作者、年份、辅助说明）
    static let inkSecondary = dynamic(
        light: hex(0x565B67),
        dark:  hex(0x9CA2B0)
    )

    /// 三级文字（占位符、计数、微缩提示）
    static let inkTertiary = dynamic(
        light: hex(0x8D93A1),
        dark:  hex(0x636877)
    )

    /// 主强调色：现代艺术画廊风格的克莱因深青蓝 / 极光靛蓝（Electric Klein Indigo）
    static let accent = dynamic(
        light: hex(0x3563E9),
        dark:  hex(0x5B82F6)
    )

    /// 强调色的浅雾底色（选中态背景、药丸指示器）
    static let accentWash = dynamic(
        light: hex(0x3563E9, alpha: 0.10),
        dark:  hex(0x5B82F6, alpha: 0.18)
    )

    /// 发丝分隔线（精细低对比度，消解视觉杂乱）
    static let rule = dynamic(
        light: hex(0x000000, alpha: 0.07),
        dark:  hex(0xFFFFFF, alpha: 0.08)
    )

    /// 悬停微光
    static let hoverFill = dynamic(
        light: hex(0x000000, alpha: 0.04),
        dark:  hex(0xFFFFFF, alpha: 0.06)
    )

    // MARK: - 阴影与光效

    /// 封面静止时的环境柔光阴影
    static let coverShadow = Color.black.opacity(0.08)
    
    /// 卡片悬停提升时的深度阴影
    static let coverHoverShadow = Color.black.opacity(0.18)

    // MARK: - 尺寸与网格

    static let cardWidth: CGFloat = 172
    /// 封面展示槽高度（基于 2:3 经典海报/书籍长宽比）
    static let coverWellHeight: CGFloat = cardWidth * 1.5

    /// 现代连续曲率圆角
    static let cardRadius: CGFloat = 8
    static let controlRadius: CGFloat = 7
    static let panelRadius: CGFloat = 12

    static let contentPadding: CGFloat = 28
    static let gridSpacing: CGFloat = 24
    static let rowSpacing: CGFloat = 30

    // MARK: - 字体层次系统 (Typography)

    /// 页眉大标题：现代有力、排版舒展
    static let pageTitle = Font.system(size: 26, weight: .bold, design: .default)

    /// 小节栏目标题
    static func serifTitle(_ size: CGFloat = 15, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }

    /// 副标题
    static let byline = Font.system(size: 13, weight: .regular)

    /// 叙述性正文（简介、感想）
    static func serifBody(_ size: CGFloat = 13.5) -> Font {
        .system(size: size, weight: .regular)
    }

    static func title(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .semibold)
    }

    static let cardTitle = Font.system(size: 13, weight: .semibold)
    static let cardMeta = Font.system(size: 11, weight: .regular)
    static let body = Font.system(size: 13, weight: .regular)
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

// MARK: - 通用小节标头

struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(ArtShelfStyle.inkTertiary)
    }
}

// MARK: - 精致发丝线

struct PaperRule: View {
    var body: some View {
        Rectangle()
            .fill(ArtShelfStyle.rule)
            .frame(height: 1)
    }
}

// MARK: - 状态胶囊徽标

struct StatusBadge: View {
    let status: MediaStatus
    let type: MediaType

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 5, height: 5)
            Text(status.label(for: type))
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(
            Capsule()
                .fill(status.color.opacity(0.12))
        )
        .foregroundStyle(status.color)
    }
}

// MARK: - 复用修饰符

extension View {
    /// 控件微底（输入框、胶囊按钮）
    func wellBackground(radius: CGFloat = ArtShelfStyle.controlRadius) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(ArtShelfStyle.well)
        )
    }

    /// 面板底：质感浮层表面，带极细微描边
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

    /// 卡片悬停微浮效果
    func cardHoverEffect(isHovered: Bool) -> some View {
        self
            .offset(y: isHovered ? -3 : 0)
            .shadow(
                color: isHovered ? ArtShelfStyle.coverHoverShadow : ArtShelfStyle.coverShadow,
                radius: isHovered ? 12 : 5,
                x: 0,
                y: isHovered ? 6 : 2
            )
            .animation(.easeOut(duration: 0.18), value: isHovered)
    }

    /// 隐藏滚动条与滚动槽，保留原生平滑触控滚动
    func hideScrollIndicators() -> some View {
        self
            .scrollIndicators(.hidden)
            .background(ScrollbarSanitizer())
    }
}

// MARK: - 安全无侵入滚动条隐形器

/// 专为 macOS 滚动视图定制的无侵入零宽度透明滚动条子类
final class InvisibleScroller: NSScroller {
    override class func scrollerWidth(for controlSize: NSControl.ControlSize, scrollerStyle: NSScroller.Style) -> CGFloat {
        0
    }

    override class var isCompatibleWithOverlayScrollers: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {}
    override func drawKnob() {}
    override func drawKnobSlot(in slotRect: NSRect, highlight: Bool) {}

    override var isHidden: Bool {
        get { true }
        set {}
    }

    override var alphaValue: CGFloat {
        get { 0 }
        set {}
    }
}

struct ScrollbarSanitizer: NSViewRepresentable {
    func makeNSView(context: Context) -> SanitizerView {
        SanitizerView()
    }

    func updateNSView(_ nsView: SanitizerView, context: Context) {
        nsView.sanitize()
    }
}

final class SanitizerView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        sanitize()
    }

    override func layout() {
        super.layout()
        sanitize()
    }

    func sanitize() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let enclosing = self.enclosingScrollView {
                self.sanitizeScrollView(enclosing)
            }
            if let root = self.window?.contentView {
                self.walkAndSanitize(root)
            }
        }
    }

    private func walkAndSanitize(_ view: NSView) {
        if let sv = view as? NSScrollView {
            sanitizeScrollView(sv)
        }
        for sub in view.subviews {
            walkAndSanitize(sub)
        }
    }

    private func sanitizeScrollView(_ sv: NSScrollView) {
        sv.scrollerStyle = .overlay
        sv.autohidesScrollers = true
        if !(sv.verticalScroller is InvisibleScroller) {
            sv.verticalScroller = InvisibleScroller()
        }
        if !(sv.horizontalScroller is InvisibleScroller) {
            sv.horizontalScroller = InvisibleScroller()
        }
        sv.verticalScroller?.isHidden = true
        sv.horizontalScroller?.isHidden = true
        sv.verticalScroller?.alphaValue = 0
        sv.horizontalScroller?.alphaValue = 0
        sv.scrollerInsets = NSEdgeInsetsZero
    }
}
