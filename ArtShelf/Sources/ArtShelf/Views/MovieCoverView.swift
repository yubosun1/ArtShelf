import SwiftUI
import AppKit

/// 专为“影视”类型打造的典藏海报组件 (Cinematic Archive Poster)
///
/// 与黑胶碟片滑出封套、书籍翻开露出纸页同构的“实体介质藏在封面后”设计语言：
/// 1. 经典 2:3 大画幅海报满幅展开，覆以影院级透光亚克力微光泽（对角白渐变 + screen 混合），
///    海报本体不做任何缩放与位移——交互全部集中在胶片条上；
/// 2. 海报右后方藏着一条 35mm 典藏级物理胶片底片——深棕黑半透明片基、左右对称冲孔片孔、
///    纵向微缩画格（原画底片 + 暖橙负片罩染）与柯达胶卷工业边码；
/// 3. 三态参数化：静止时胶片条仅探出一截片头标识媒介属性，悬停轻盈滑出并伴随微角度偏转，
///    详情页常驻展呈态（alwaysExtended）滑出最多并定格展示；
/// 4. 遵循系统“减弱动态效果”设置：开启时胶片条不滑动不偏转，保持静止探出量。
struct MovieCoverView: View {

    let localPath: String?
    let remoteURL: String?
    let size: CGFloat          // 宽度基准
    let cornerRadius: CGFloat
    var isHovered: Bool = false
    var alwaysExtended: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    /// 海报高度 (严格 2:3 纵横比)
    private var posterHeight: CGFloat {
        size * 1.5
    }

    // MARK: - 三态参数化（静止 idle / 悬停 hover / 常驻展呈 alwaysExtended）

    /// 是否处于展呈态（悬停交互或详情页常驻），仅用于亚克力微光泽强度
    private var isPresenting: Bool {
        alwaysExtended || isHovered
    }

    /// 统一的胶片条滑出动画（与黑胶碟片同一节奏）
    private var filmSpring: Animation {
        .spring(response: 0.38, dampingFraction: 0.72)
    }

    /// 胶片条向右探出海报边缘的距离：
    /// 静止常驻露出一截片头，悬停滑出更多，详情页滑出最多定格；
    /// 减弱动态时不滑动，保持静止探出量
    private var filmPeek: CGFloat {
        guard !reduceMotion else { return size * 0.10 }
        if alwaysExtended {
            // 详情页等常驻展示模式：大幅抽出展示片格全貌
            return size * 0.24
        } else if isHovered {
            // 悬停交互模式：轻盈滑出
            return size * 0.20
        } else {
            // 静止状态：常驻探出一截片头，标识其影视胶片属性
            return size * 0.10
        }
    }

    /// 胶片条微角度偏转：悬停与常驻展呈时如被指尖轻轻抽出般倾斜；减弱动态时不偏转
    private var filmRotation: Double {
        guard !reduceMotion else { return 0 }
        if alwaysExtended {
            return 4
        } else if isHovered {
            return 3
        } else {
            return 0
        }
    }

    // MARK: - 胶片条几何（随画幅缩放）

    /// 胶片条宽度
    private var stripWidth: CGFloat {
        size * 0.24
    }

    /// 胶片条高度（略短于海报，竖向藏于海报正后方）
    private var stripHeight: CGFloat {
        posterHeight * 0.94
    }

    /// 单个片孔宽度（仿 35mm 胶片横宽竖短的矩形冲孔）
    private var perforationWidth: CGFloat {
        stripWidth * 0.15
    }

    /// 单个片孔高度
    private var perforationHeight: CGFloat {
        perforationWidth * 0.72
    }

    /// 片孔纵向间隔
    private var perforationGap: CGFloat {
        perforationWidth * 0.6
    }

    /// 片孔列距片基边缘的内缩
    private var perforationInset: CGFloat {
        stripWidth * 0.05
    }

    /// 单侧片孔数量（按胶片条高度均布）
    private var perforationCount: Int {
        let pitch = perforationHeight + perforationGap
        return max(3, Int((stripHeight * 0.88) / pitch))
    }

    /// 微缩画格宽度（位于两列片孔之间）
    private var frameCellWidth: CGFloat {
        stripWidth * 0.46
    }

    /// 微缩画格高度（与海报同 2:3 原画比例）
    private var frameCellHeight: CGFloat {
        frameCellWidth * 1.5
    }

    /// 画格纵向间隔（间隔处露出的深色片基即天然画格黑框）
    private var frameCellGap: CGFloat {
        frameCellWidth * 0.30
    }

    /// 画格数量（3-4 格，按胶片条高度均布）
    private var frameCellCount: Int {
        let pitch = frameCellHeight + frameCellGap
        return min(4, max(3, Int((stripHeight * 0.66) / pitch)))
    }

    /// 画格与片孔列之间的窄隙宽度（工业边码放置处）
    private var edgeCodeLane: CGFloat {
        (stripWidth - 2 * (perforationInset + perforationWidth) - frameCellWidth) / 2
    }

    /// 工业边码字号（随画幅缩放，略溢出窄隙更贴近真实边印）
    private var edgeCodeFontSize: CGFloat {
        edgeCodeLane * 1.15
    }

    /// 是否绘制工业边码（迷你封面下微缩字会糊成色点，仅画幅足够大时绘制）
    private var showsEdgeCode: Bool {
        size >= 150
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // 1. 底层：藏在海报右后方的 35mm 胶片底片条（悬停/常驻展呈时向右滑出）
            filmStrip
                .offset(x: filmPeek)
                .rotationEffect(.degrees(filmRotation))
                .animation(filmSpring, value: isHovered)
                .animation(filmSpring, value: alwaysExtended)

            // 2. 表层：经典 2:3 海报（本体不动，与封套不动碟片滑出的逻辑一致）
            posterFront
        }
        .frame(width: size, height: posterHeight)
    }

    // MARK: - 海报（前方）

    private var posterFront: some View {
        ZStack(alignment: .topTrailing) {
            // 海报主图（满幅 2:3 原生比例呈现）
            CoverImageView(
                localPath: localPath,
                remoteURL: remoteURL,
                aspectRatio: 2.0 / 3.0,
                cornerRadius: cornerRadius
            )
            .frame(width: size, height: posterHeight)

            // 影院级透光亚克力微光泽（对角白渐变 + 屏幕混合）
            glassSheen

            // 发丝级画框微高光与内阴影边缘
            hairlineBorder
        }
        .frame(width: size, height: posterHeight)
    }

    /// 影院画框玻璃反光（模拟亚克力覆膜微反光与对角漫射）
    private var glassSheen: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isPresenting ? 0.16 : 0.08),
                        Color.white.opacity(0.02),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .blendMode(.screen)
            .frame(width: size, height: posterHeight)
            .allowsHitTesting(false)
    }

    /// 外围发丝边框
    private var hairlineBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isPresenting ? 0.28 : 0.16),
                        Color.white.opacity(0.06),
                        Color.black.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.6
            )
            .frame(width: size, height: posterHeight)
            .allowsHitTesting(false)
    }

    // MARK: - 35mm 典藏胶片底片条 (Archive Film Strip)

    private var filmStrip: some View {
        ZStack {
            // 深棕黑半透明片基
            filmBase

            // 左右两列对称冲孔片孔
            perforationColumns

            // 中间纵向微缩画格（原画底片 + 暖橙负片罩染）
            frameCells

            // 柯达胶卷工业边码（沿片边竖排）
            if showsEdgeCode {
                edgeCode
            }

            // 片基纵向纹理与圆柱面高光
            filmSheen
        }
        .frame(width: stripWidth, height: stripHeight)
        // 片身内置阴影从轻（卡片级阴影由外层 cardHoverEffect 兜底）
        .shadow(color: Color.black.opacity(0.28), radius: 2, x: 1, y: 1)
        // 整体光栅化为位图：片基渐变、冲孔与画格只合成一次，
        // 悬停滑出 / 偏转动画退化为 GPU transform，不再逐帧重绘矢量（与黑胶碟片同一做法）
        .drawingGroup()
        .allowsHitTesting(false)
    }

    /// 片基：深棕黑半透明醋酸片基，纵向微渐变 + 边缘厚度描边
    private var filmBase: some View {
        RoundedRectangle(cornerRadius: stripWidth * 0.12, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.17, green: 0.12, blue: 0.08),
                        Color(red: 0.10, green: 0.07, blue: 0.05),
                        Color(red: 0.07, green: 0.05, blue: 0.04)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .opacity(0.94)
            .overlay(
                RoundedRectangle(cornerRadius: stripWidth * 0.12, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.14),
                                Color.black.opacity(0.5)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
    }

    /// 左右两列对称冲孔片孔
    private var perforationColumns: some View {
        HStack {
            perforationColumn
            Spacer()
            perforationColumn
        }
        .padding(.horizontal, perforationInset)
        .padding(.vertical, stripHeight * 0.03)
    }

    /// 单侧竖向片孔列：透光的暖象牙色冲孔，带细微压暗影描边
    private var perforationColumn: some View {
        VStack(spacing: perforationGap) {
            ForEach(0..<perforationCount, id: \.self) { _ in
                RoundedRectangle(cornerRadius: perforationHeight * 0.3, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.98, green: 0.95, blue: 0.88).opacity(0.9),
                                Color(red: 0.90, green: 0.85, blue: 0.75).opacity(0.55)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: perforationHeight * 0.3, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.35), lineWidth: 0.5)
                    )
                    .frame(width: perforationWidth, height: perforationHeight)
            }
        }
    }

    /// 中间纵向微缩画格列（3-4 格，格间露出的片基即天然黑框）
    private var frameCells: some View {
        VStack(spacing: frameCellGap) {
            ForEach(0..<frameCellCount, id: \.self) { _ in
                frameCell
            }
        }
    }

    /// 单格微缩画格：原画海报底片 + 暖橙负片罩染（彩色负片的橙色蒙罩质感）
    private var frameCell: some View {
        ZStack {
            // 画格底（无图时的深琥珀片基色）
            Color(red: 0.32, green: 0.18, blue: 0.08)

            // 微缩原画（小尺寸 256px 走 ImageCache，与封面视图同源缓存，通常直接命中）
            if let localPath, let nsImage = ImageCache.shared.image(atPath: localPath, maxPixelSize: 256) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let remoteURL, let url = URL(string: remoteURL) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                }
            }

            // 暖橙负片罩染
            Color(red: 0.86, green: 0.45, blue: 0.16).opacity(0.34)
        }
        .frame(width: frameCellWidth, height: frameCellHeight)
        .clipShape(RoundedRectangle(cornerRadius: 1, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .strokeBorder(Color.black.opacity(0.55), lineWidth: 0.6)
        )
    }

    /// 柯达胶卷工业边码：沿片边竖排的微缩字标，置于画格与片孔列之间的窄隙
    private var edgeCode: some View {
        Text("KODAK 5248")
            .font(.system(size: edgeCodeFontSize, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color(red: 0.95, green: 0.80, blue: 0.55).opacity(0.6))
            .fixedSize()
            .rotationEffect(.degrees(90))
            .offset(x: frameCellWidth / 2 + edgeCodeLane / 2)
    }

    /// 片基纵向纹理：横向渐变营造圆柱面明暗与一道纵向高光
    private var filmSheen: some View {
        RoundedRectangle(cornerRadius: stripWidth * 0.12, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.30),
                        Color.clear,
                        Color.white.opacity(0.10),
                        Color.clear,
                        Color.black.opacity(0.35)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
}
