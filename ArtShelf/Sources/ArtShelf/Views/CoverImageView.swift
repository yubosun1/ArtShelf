import SwiftUI
import AppKit

/// 统一的封面图片视图——支持本地文件 / 远程 URL / 占位符
///
/// 布局完全由 `aspectRatio` 与外部给定的宽度决定，绝不依赖图片的固有像素尺寸；
/// 否则一张 2000px 宽的远程封面会把所在行撑破。
struct CoverImageView: View {

    let localPath: String?
    let remoteURL: String?
    let aspectRatio: CGFloat   // width / height
    let cornerRadius: CGFloat

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
            .shadow(color: ArtShelfStyle.coverShadow, radius: 3, x: 0, y: 2)
    }

    @ViewBuilder
    private var artwork: some View {
        if let localPath, let image = NSImage(contentsOfFile: localPath) {
            fill(Image(nsImage: image))
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
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.tertiary)
            }
    }
}
