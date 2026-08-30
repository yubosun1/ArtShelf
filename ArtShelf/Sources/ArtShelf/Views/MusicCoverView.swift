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
        .shadow(color: ArtShelfStyle.coverShadow, radius: 4, x: -1, y: 2)
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
        .shadow(color: Color.black.opacity(0.32), radius: 6, x: 3, y: 3)
    }

    // MARK: - 同心音轨

    private var grooveRings: some View {
        ZStack {
            // 多层同心音轨模拟真实压胶盘微细纹理
            ForEach([0.88, 0.82, 0.76, 0.70, 0.64, 0.58, 0.52], id: \.self) { ratio in
                Circle()
                    .strokeBorder(
                        Color.white.opacity(0.06),
                        style: StrokeStyle(lineWidth: 0.6, dash: [4, 1.5])
                    )
                    .frame(width: discDiameter * ratio, height: discDiameter * ratio)
            }

            ForEach([0.85, 0.79, 0.73, 0.67, 0.61, 0.55, 0.48], id: \.self) { ratio in
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

            // 如果有封面图，中心标内部柔和显示微缩封面
            if let localPath, let nsImage = NSImage(contentsOfFile: localPath) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: labelSize * 0.78, height: labelSize * 0.78)
                    .clipShape(Circle())
                    .opacity(0.85)
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
    }
}
