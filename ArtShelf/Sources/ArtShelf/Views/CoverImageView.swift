import SwiftUI
import AppKit

/// 统一的封面图片视图——支持本地文件 / 远程 URL / 占位符
///
/// 布局完全由 `aspectRatio` 与外部给定的宽度决定，绝不依赖图片的固有像素尺寸；
/// 否则一张 2000px 宽的远程封面会把所在行撑破。
///
/// 本地图片走 `ImageCache` 缓存：body 里先同步查缓存（命中零成本），
/// 未命中先显示占位符，再由后台任务缩小解码后回填——避免网格滚动时
/// 在 body 求值路径里全尺寸同步解码大图造成卡顿。
struct CoverImageView: View {

    let localPath: String?
    let remoteURL: String?
    let aspectRatio: CGFloat   // width / height
    let cornerRadius: CGFloat

    /// 本地封面缩略解码的像素上限（卡片 172pt@2x≈344、详情 220pt@2x≈440，留余量）
    private static let maxPixelSize = 600

    /// 后台解码完成后的本地封面图（nil 表示未加载完成，显示占位符）
    @State private var localImage: NSImage?

    init(localPath: String?, remoteURL: String?, aspectRatio: CGFloat, cornerRadius: CGFloat = 8) {
        self.localPath = localPath
        self.remoteURL = remoteURL
        self.aspectRatio = aspectRatio
        self.cornerRadius = cornerRadius
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        // Color 没有固有尺寸，它只接受外部提议——这里是尺寸的唯一来源。
        Color.clear
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay { artwork }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            }
            .shadow(color: ArtShelfStyle.coverShadow, radius: 2, x: 0, y: 1)
            .task(id: localPath) {
                await loadLocalImage()
            }
    }

    @ViewBuilder
    private var artwork: some View {
        if let localPath {
            // 1. 缓存命中：零成本直接展示（无需等待异步回填）
            if let cached = ImageCache.shared.cachedImage(atPath: localPath, maxPixelSize: Self.maxPixelSize) {
                fill(Image(nsImage: cached))
            } else if let image = localImage {
                // 2. 本视图此前异步加载好的结果
                fill(Image(nsImage: image))
            } else {
                // 3. 未命中：先用占位符，由 .task 后台解码后回填
                placeholder
            }
        } else if let remoteURL, let url = URL(string: remoteURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    fill(image)
                default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    /// 后台缩小解码本地封面并回填。
    /// 回填前会比对路径：异步期间 cell 可能已被复用为其他条目（如列表滚动），
    /// 路径不一致时丢弃结果，避免张冠李戴。
    @MainActor
    private func loadLocalImage() async {
        guard let localPath else {
            localImage = nil
            return
        }
        // 路径变化时先清掉旧图，避免复用期间短暂显示上一张图
        localImage = nil

        // 解码由 ImageCache 内部有界并发队列执行（同时最多 3 个），
        // 同路径+尺寸的并发请求自动合并——网格快速滚动时不会再出现
        // 几十个 cell 各自起 detached 任务无限并发读盘解码抢 CPU 的情况
        let image = await ImageCache.shared.imageAsync(atPath: localPath, maxPixelSize: Self.maxPixelSize)

        // 回填前校验当前路径未变（防 cell 复用错图）
        guard self.localPath == localPath else { return }
        localImage = image
    }

    /// `.fill` + clipped，让图片在固定容器内裁切而不是反过来撑大容器。
    private func fill(_ image: Image) -> some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fill)
            .clipped()
    }

    private var placeholder: some View {
        ArtShelfStyle.well
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 24, weight: .ultraLight))
                    .foregroundStyle(.tertiary)
            }
    }
}