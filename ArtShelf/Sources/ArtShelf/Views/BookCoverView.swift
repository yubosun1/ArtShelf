import SwiftUI
import AppKit

/// 专为“书籍”类型打造的封面侧边翻卷动效组件 (Side-Curl Cover Atelier)
///
/// 仿真真实书页被指尖从侧边捻起的翻卷：
/// 1. 封面整体保持平整，仅右侧自由边沿一条近垂直的剥离线被微微捻起——以剥离线为轴向读者翻卷，
///    不做整盖旋转、不做封面压缩（真实封面不会整体掀起或弯曲变形）；
/// 2. 剥离线下端略宽于上端（模拟从下方捻起的手势），翻卷处在封面主体上镂空，
///    露出下方一整张环衬页纸面，卷得越多露出越多；
/// 3. 卷起的侧边在纸面上投下沿剥离线渐淡的柔和阴影，卷面近自由边处泛出纸白，暗示纸张背面。
/// 遵循系统“减弱动态效果”偏好：开启时不翻卷，保持静态封面。
struct BookCoverView: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let localPath: String?
    let remoteURL: String?
    let size: CGFloat          // 宽度基准
    let cornerRadius: CGFloat
    var isHovered: Bool = false
    var alwaysExtended: Bool = false

    init(
        localPath: String?,
        remoteURL: String?,
        size: CGFloat = ArtShelfStyle.cardWidth,
        cornerRadius: CGFloat = ArtShelfStyle.cardRadius,
        isHovered: Bool = false,
        alwaysExtended: Bool = false
    ) {
        self.localPath = localPath
        self.remoteURL = remoteURL
        self.size = size
        self.cornerRadius = cornerRadius
        self.isHovered = isHovered
        self.alwaysExtended = alwaysExtended
    }

    /// 书籍高度 (严格 2:3 纵横比)
    private var bookHeight: CGFloat {
        size * 1.5
    }

    /// 当前是否处于翻卷状态
    private var isFlipped: Bool {
        alwaysExtended || isHovered
    }

    /// 实际生效的翻卷状态（开启“减弱动态效果”时保持静态）
    private var effectiveFlip: Bool {
        reduceMotion ? false : isFlipped
    }

    /// 统一的翻卷动画
    private var flipSpring: Animation {
        .spring(response: 0.42, dampingFraction: 0.70)
    }

    // MARK: - 翻卷几何

    /// 剥离线上端距右缘的宽度（翻卷区顶部宽度）
    private var peelTop: CGFloat { size * 0.26 }

    /// 剥离线下端距右缘的宽度（翻卷区底部更宽，模拟从下方捻起）
    private var peelBottom: CGFloat { size * 0.34 }

    /// 剥离线中点——翻卷旋转的锚点（单位坐标）
    private var peelAnchor: UnitPoint {
        UnitPoint(x: 1 - (peelTop + peelBottom) / (2 * size), y: 0.5)
    }

    /// 翻卷旋转轴：沿剥离线的近垂直方向（已归一化），负角度把自由边卷向读者
    private var peelAxis: (x: CGFloat, y: CGFloat, z: CGFloat) {
        let length = hypot(peelTop - peelBottom, bookHeight)
        return ((peelTop - peelBottom) / length, bookHeight / length, 0)
    }

    /// 翻卷角度（微微掀起）
    private var curlAngle: Double {
        effectiveFlip ? -20 : 0
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 1. 底层：底部与右侧露出的实体书页厚度切口 (Stacked Page Block Base)
            stackedPagesBase

            // 2. 内层：翻卷处露出的环衬页纸面 (Exposed Flyleaf)
            underneathReadingPage

            // 3. 卷起的侧边投在纸面上的阴影 (Curl Cast Shadow)
            curlPaperShadow
                .opacity(effectiveFlip ? 1.0 : 0.0)
                .animation(flipSpring, value: isHovered)
                .animation(flipSpring, value: alwaysExtended)

            // 4. 封面主体（右侧镂空翻卷区）
            coverBody
                .zIndex(isFlipped ? 3 : 1)

            // 5. 翻卷起的封面侧边 (Curled Side Flap)
            curledFlap
                .zIndex(isFlipped ? 4 : 2)
        }
        .frame(width: size, height: bookHeight)
        // 整书外部环境立体投影
        .shadow(
            color: Color.black.opacity(0.12),
            radius: 2,
            x: 0,
            y: 1
        )
        .shadow(
            color: effectiveFlip ? Color.black.opacity(0.18) : Color.black.opacity(0.10),
            radius: effectiveFlip ? 10 : 5,
            x: effectiveFlip ? 2 : 1,
            y: effectiveFlip ? 4 : 2
        )
        .animation(flipSpring, value: isHovered)
        .animation(flipSpring, value: alwaysExtended)
    }

    // MARK: - 1. 底部与右侧实体书页层叠切口 (Stacked Pages Base)

    private var stackedPagesBase: some View {
        ZStack(alignment: .bottomTrailing) {
            // 底部与右侧微微延伸的书页底座
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.93, green: 0.91, blue: 0.86),
                            Color(red: 0.89, green: 0.87, blue: 0.81)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    // 底部多层纸张叠切细线
                    VStack(spacing: 1.2) {
                        Spacer()
                        ForEach(0..<3, id: \.self) { _ in
                            Rectangle()
                                .fill(Color(red: 0.75, green: 0.72, blue: 0.66).opacity(0.55))
                                .frame(height: 0.6)
                        }
                    }
                    .padding(.bottom, 1.5)
                    .padding(.horizontal, 4)
                )
                .frame(width: size, height: bookHeight)
                .offset(x: 2.5, y: 3.5)
        }
    }

    // MARK: - 2. 翻卷处露出的环衬页 (Exposed Flyleaf)

    /// 翻开封面后露出的一整张平铺环衬页——真实书本翻开看到的是平铺纸面，而非层叠切口
    private var underneathReadingPage: some View {
        RoundedRectangle(cornerRadius: max(2, cornerRadius - 2), style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.94, green: 0.92, blue: 0.87),
                        Color(red: 0.97, green: 0.955, blue: 0.91)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(alignment: .leading) {
                // 装订缝：环衬页在脊侧陷入订口的柔和阴影
                LinearGradient(
                    colors: [Color.black.opacity(0.16), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: size * 0.14)
            }
            // 精装书壳略大于内页：顶/底/右三边留出少许壳沿，脊侧齐平
            .padding(.top, 2)
            .padding(.bottom, 3)
            .padding(.trailing, 3)
            .frame(width: size, height: bookHeight, alignment: .topLeading)
    }

    // MARK: - 3. 卷边投在环衬页上的阴影 (Curl Cast Shadow)

    /// 沿剥离线渐淡的竖向投影带——卷起的侧边遮挡光线所致
    private var curlPaperShadow: some View {
        HStack(spacing: 0) {
            Spacer()
            LinearGradient(
                colors: [Color.black.opacity(0.13), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: size * 0.38, height: bookHeight)
        }
        .frame(width: size, height: bookHeight)
        .allowsHitTesting(false)
    }

    // MARK: - 4. 封面主体（镂空翻卷区）

    private var coverBody: some View {
        ZStack(alignment: .topTrailing) {
            // 封面图片本体
            CoverImageView(
                localPath: localPath,
                remoteURL: remoteURL,
                aspectRatio: 2.0 / 3.0,
                cornerRadius: cornerRadius
            )
            .frame(width: size, height: bookHeight)

            hairlineBorder
        }
        .frame(width: size, height: bookHeight)
        // 右侧镂空翻卷区，露出下方环衬页
        .mask(PeelCutShape(peelTop: peelTop, peelBottom: peelBottom).fill(style: FillStyle(eoFill: true)))
    }

    // MARK: - 5. 翻卷起的封面侧边 (Curled Side Flap)

    private var curledFlap: some View {
        ZStack(alignment: .topTrailing) {
            // 与封面主体同源的侧边切片
            CoverImageView(
                localPath: localPath,
                remoteURL: remoteURL,
                aspectRatio: 2.0 / 3.0,
                cornerRadius: cornerRadius
            )
            .frame(width: size, height: bookHeight)

            // 卷面光影：剥离线处微暗（纸面转入卷曲），中部受光，自由边泛纸白暗示背面
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.10), location: 0.0),
                    .init(color: Color.clear, location: 0.30),
                    .init(color: Color.white.opacity(0.20), location: 0.58),
                    .init(color: Color.white.opacity(0.08), location: 0.78),
                    .init(color: Color(red: 0.97, green: 0.955, blue: 0.91).opacity(0.55), location: 1.0)
                ],
                startPoint: UnitPoint(x: 0.72, y: 0.5),
                endPoint: .trailing
            )
            .opacity(effectiveFlip ? 1.0 : 0.0)
            .allowsHitTesting(false)

            edgeGlint
            hairlineBorder
        }
        .frame(width: size, height: bookHeight)
        .clipShape(PeelFlapShape(peelTop: peelTop, peelBottom: peelBottom))
        // 以剥离线为轴微微卷向读者
        .rotation3DEffect(
            .degrees(curlAngle),
            axis: peelAxis,
            anchor: peelAnchor,
            anchorZ: 0,
            perspective: 0.55
        )
        .shadow(
            color: Color.black.opacity(effectiveFlip ? 0.22 : 0.0),
            radius: 3,
            x: -2,
            y: 0
        )
        .animation(flipSpring, value: isHovered)
        .animation(flipSpring, value: alwaysExtended)
        .allowsHitTesting(false)
    }

    // MARK: - 封面共用装饰

    /// 封面板的侧边厚度反光（硬质板沿，随翻卷侧边走）
    private var edgeGlint: some View {
        HStack {
            Spacer()
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color(red: 0.98, green: 0.96, blue: 0.92).opacity(effectiveFlip ? 0.35 : 0.08)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 2.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .frame(width: size, height: bookHeight)
        .allowsHitTesting(false)
    }

    /// 外围发丝边框
    private var hairlineBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(effectiveFlip ? 0.28 : 0.16),
                        Color.white.opacity(0.04),
                        Color.black.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.6
            )
            .frame(width: size, height: bookHeight)
            .allowsHitTesting(false)
    }
}

/// 封面翻卷的侧边 flap 区域（近垂直剥离线与右缘围成的梯形）
private struct PeelFlapShape: Shape {
    var peelTop: CGFloat     // 剥离线上端距右缘宽度
    var peelBottom: CGFloat  // 剥离线下端距右缘宽度

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX - peelTop, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - peelBottom, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// 封面主体轮廓：整幅矩形镂空 flap 梯形（even-odd 填充），翻卷处露出下方纸张
private struct PeelCutShape: Shape {
    var peelTop: CGFloat
    var peelBottom: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRect(rect)
        p.move(to: CGPoint(x: rect.maxX - peelTop, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - peelBottom, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
