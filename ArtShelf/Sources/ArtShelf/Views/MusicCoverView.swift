import SwiftUI
import AppKit

/// 专为“音乐”类型打造的黑胶唱片封套组件 (Music Vinyl Atelier Cover)
///
/// 具备三大专属优化：
/// 1. 严格 1:1 方形装帧封套，左侧模拟实体黑胶的书脊折痕压痕（Spine Crease）；
/// 2. 封套右侧开口探出高精度矢量黑胶唱片（同心音轨、径向双光锥反射、中央标签与转轴孔）；
/// 3. 悬停与交互时，黑胶碟片轻柔滑出并伴随微角度旋转，带来极其细腻的实体把玩感。
struct MusicCoverView: View {

    let localPath: String?
    let remoteURL: String?
    let size: CGFloat
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

    /// 封套比例系数（详情页中唱片大幅抽出，封套占比稍小）
    private var sleeveRatio: CGFloat {
        alwaysExtended ? 0.82 : 0.88
    }

    /// 中心标微缩封面解码像素上限（标签直径约 discDiameter*0.36 ≈ 62pt，@2x≈124，256 足够）
    private static let labelPixelSize = 256

    /// 后台解码完成后的中心标微缩封面（nil 表示未加载完成，仅显示标签底色）
    @State private var labelImage: NSImage?

    /// 封套本体尺寸
    private var sleeveSize: CGFloat {
        size * sleeveRatio
    }

    /// 唱片碟片直径
    private var discDiameter: CGFloat {
        sleeveSize * 0.94
    }

    /// 黑胶唱片右向滑出偏移量
    private var discOffset: CGFloat {
        if alwaysExtended {
            // 详情页等常驻展示模式：大幅展开展示碟面全貌
            return sleeveSize * 0.28
        } else if isHovered {
            // 悬停交互模式：自然滑出
            return sleeveSize * 0.22
        } else {
            // 静止状态：常驻露出精致圆弧边缘，标识其黑胶音乐属性
            return sleeveSize * 0.12
        }
    }

    /// 黑胶唱片旋转角度
    private var discRotation: Double {
        if alwaysExtended {
            return 28
        } else if isHovered {
            return 22
        } else {
            return 0
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // 1. 底层：探出的黑胶唱片
            vinylDisc
                .offset(x: discOffset)
                .rotationEffect(.degrees(discRotation))
                .animation(.spring(response: 0.38, dampingFraction: 0.72), value: isHovered)
                .animation(.spring(response: 0.38, dampingFraction: 0.72), value: alwaysExtended)

            // 2. 表层：方形黑胶封套（Jacket Sleeve）
            vinylJacket
        }
        .frame(width: size, height: size, alignment: .leading)
    }

    // MARK: - 方形黑胶封套

    private var vinylJacket: some View {
        Group {
            if alwaysExtended {
                jacketBase
                    // 详情页单张展示：保留封套阴影，把玩感更完整
                    .shadow(color: ArtShelfStyle.coverShadow, radius: 2, x: -1, y: 2)
            } else {
                // 网格模式：省掉这层阴影——封面图自带阴影 + 外层 cardHoverEffect 已兜底，
                // 少一次滚动时逐帧重合成的模糊
                jacketBase
            }
        }
    }

    private var jacketBase: some View {
        ZStack(alignment: .leading) {
            // 封面图片基底
            CoverImageView(
                localPath: localPath,
                remoteURL: remoteURL,
                aspectRatio: 1.0,
                cornerRadius: cornerRadius
            )
            .frame(width: sleeveSize, height: sleeveSize)

            // 左侧书脊压痕线（模拟黑胶硬纸板封套折痕与微高光）
            HStack(spacing: 0) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.25),
                                Color.white.opacity(0.12),
                                Color.black.opacity(0.08)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 2.5)
                    .padding(.leading, 5)

                Spacer()

                // 右侧开口内阴影（增加封套纵深感）
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.24)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 4.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .allowsHitTesting(false)
        }
        .frame(width: sleeveSize, height: sleeveSize)
    }

    // MARK: - 真实黑胶唱片碟片 (Vinyl Disc)

    private var vinylDisc: some View {
        ZStack {
            // 唱片主体深色黑胶基质
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.14, green: 0.14, blue: 0.16),
                            Color(red: 0.08, green: 0.08, blue: 0.09),
                            Color(red: 0.05, green: 0.05, blue: 0.06)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: discDiameter / 2
                    )
                )

            // 唱片外圈倒角微高光边缘
            Circle()
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)

            // 细密同心圆音轨微纹理 (Concentric Grooves)
            grooveRings

            // 各向异性光锥双侧反射 (Anisotropic Sheen)
            AngularGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.0),
                    Color.white.opacity(0.15),
                    Color.white.opacity(0.0),
                    Color.white.opacity(0.15),
                    Color.white.opacity(0.0)
                ]),
                center: .center
            )
            .blendMode(.screen)
            .clipShape(Circle())
            .opacity(0.85)

            // 内圈无声区过渡环 (Run-out Groove)
            Circle()
                .strokeBorder(Color.black.opacity(0.6), lineWidth: 3)
                .frame(width: discDiameter * 0.44, height: discDiameter * 0.44)

            // 中央唱片彩色标签 (Center Label)
            centerLabel

            // 唱片中央主轴穿孔 (Spindle Hole)
            Circle()
                .fill(Color(red: 0.04, green: 0.04, blue: 0.05))
                .frame(width: discDiameter * 0.075, height: discDiameter * 0.075)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.7)
                )
                .shadow(color: .black.opacity(0.6), radius: 1, x: 0, y: 0.5)
        }
        .frame(width: discDiameter, height: discDiameter)
        // 碟身内置阴影减半（卡片级阴影由外层 cardHoverEffect 兜底）
        .shadow(color: Color.black.opacity(0.32), radius: 3, x: 1.5, y: 1.5)
        // 整体光栅化为位图：渐变、音轨圆环与 blendMode 只合成一次，
        // 悬停滑出 / 旋转动画退化为 GPU transform，不再逐帧重绘矢量
        .drawingGroup()
    }

    // MARK: - 同心音轨

    private var grooveRings: some View {
        ZStack {
            // 同心音轨纹理——每组由 7 条减为 3 条（共 14 → 6 个描边圆），
            // 配合碟身 drawingGroup 光栅化，视觉密度不变而渲染成本大降
            ForEach([0.88, 0.72, 0.56], id: \.self) { ratio in
                Circle()
                    .strokeBorder(
                        Color.white.opacity(0.06),
                        style: StrokeStyle(lineWidth: 0.6, dash: [4, 1.5])
                    )
                    .frame(width: discDiameter * ratio, height: discDiameter * ratio)
            }

            ForEach([0.85, 0.69, 0.53], id: \.self) { ratio in
                Circle()
                    .strokeBorder(
                        Color.black.opacity(0.45),
                        lineWidth: 0.8
                    )
                    .frame(width: discDiameter * ratio, height: discDiameter * ratio)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - 唱片中心标 (Center Label)

    private var centerLabel: some View {
        let labelSize = discDiameter * 0.36

        return ZStack {
            // 标签底色：优雅艺术朱红渐变
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.82, green: 0.28, blue: 0.22),
                            Color(red: 0.65, green: 0.18, blue: 0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 如果有封面图，中心标内部柔和显示微缩封面。
            // 与 CoverImageView 同模式：body 只做零成本的缓存直查，
            // 未命中先显示标签底（黑胶中心本来就有中性底色），由 .task 后台解码回填——
            // 绝不在滚动的主线程求值路径里同步解码
            if let localPath {
                if let cached = ImageCache.shared.cachedImage(atPath: localPath, maxPixelSize: Self.labelPixelSize) {
                    // 1. 缓存命中：零成本直接展示（与封面视图同源缓存，滚动几轮后通常已命中）
                    labelArtwork(cached, labelSize: labelSize)
                } else if let image = labelImage {
                    // 2. 本视图此前异步加载好的结果
                    labelArtwork(image, labelSize: labelSize)
                }
            } else if let remoteURL, let url = URL(string: remoteURL) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: labelSize * 0.78, height: labelSize * 0.78)
                            .clipShape(Circle())
                            .opacity(0.85)
                    }
                }
            }

            // 标签内同心环修饰线与立体边缘
            Circle()
                .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.7)
                .frame(width: labelSize * 0.92, height: labelSize * 0.92)

            Circle()
                .strokeBorder(Color.black.opacity(0.25), lineWidth: 1)
        }
        .frame(width: labelSize, height: labelSize)
        .task(id: localPath) {
            await loadLabelImage()
        }
    }

    /// 中心标微缩封面：裁成圆形、半透明叠加在标签底上
    private func labelArtwork(_ image: NSImage, labelSize: CGFloat) -> some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: labelSize * 0.78, height: labelSize * 0.78)
            .clipShape(Circle())
            .opacity(0.85)
    }

    /// 后台缩小解码中心标微缩封面并回填。
    /// 回填前比对路径防 cell 复用错图——与 CoverImageView 同模式，
    /// 解码走 ImageCache 有界并发队列，同路径+尺寸的请求自动合并。
    @MainActor
    private func loadLabelImage() async {
        guard let localPath else {
            labelImage = nil
            return
        }
        // 路径变化时先清掉旧图，避免复用期间短暂显示上一张图
        labelImage = nil

        let image = await ImageCache.shared.imageAsync(atPath: localPath, maxPixelSize: Self.labelPixelSize)

        // 回填前校验当前路径未变（防 cell 复用错图）
        guard self.localPath == localPath else { return }
        labelImage = image
    }
}
