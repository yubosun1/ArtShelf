import SwiftUI
import os

/// 封面图加载器：内存缓存 + 本地封面目录 + 远程下载回填
enum CoverImageLoader {

    /// NSCache 本身线程安全；Swift 6 严格并发下以 nonisolated(unsafe) 显式声明共享
    nonisolated(unsafe) private static let memory = NSCache<NSString, NSImage>()
    private static let logger = Logger(subsystem: "ArtShelf", category: "CoverImageLoader")

    static func cached(_ id: UUID) -> NSImage? {
        memory.object(forKey: id.uuidString as NSString)
    }

    /// 加载封面：本地缓存文件 → 远程 URL 下载并回填到 covers 目录
    /// - Returns: (图片, 下载后回填的本地路径)。回填路径由调用方写入模型。
    static func load(for item: MediaItem) async -> (NSImage, String?)? {
        if let hit = cached(item.id) { return (hit, nil) }

        // 本地文件
        if let path = item.localCoverPath,
           let image = NSImage(contentsOfFile: path) {
            memory.setObject(image, forKey: item.id.uuidString as NSString)
            return (image, nil)
        }

        // 远程下载
        guard let urlString = item.coverURL, let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = NSImage(data: data) else { return nil }
            let path = LibraryPaths.coversDirectory.appendingPathComponent("\(item.id.uuidString).jpg")
            try? data.write(to: path)
            memory.setObject(image, forKey: item.id.uuidString as NSString)
            return (image, path.path)
        } catch {
            logger.error("封面下载失败: \(error, privacy: .public)")
            return nil
        }
    }
}

/// 封面视图：平铺封面（v3 取消拟物装帧），可选上报主色供光晕使用
struct CoverImageView: View {

    let item: MediaItem
    var cornerRadius: CGFloat = Theme.cardCorner
    var onDominantColor: ((Color?) -> Void)? = nil

    @Environment(LibraryStore.self) private var store
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.well)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: item.id) { await load() }
    }

    private var placeholder: some View {
        ZStack {
            Theme.well
            VStack(spacing: 6) {
                Image(systemName: item.type.systemImage)
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(Theme.ink3)
                Text(item.title)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.ink3)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
    }

    private func load() async {
        guard let result = await CoverImageLoader.load(for: item) else {
            onDominantColor?(nil)
            return
        }
        let (loaded, backfillPath) = result
        image = loaded
        // 下载成功的封面回填本地路径（一次性）
        if let backfillPath {
            store.backfillCover(id: item.id, path: backfillPath)
        }
        if let onDominantColor {
            let color = await Task.detached(priority: .utility) {
                loaded.dominantColor()
            }.value
            onDominantColor(color.map(Color.init(nsColor:)))
        }
    }
}
