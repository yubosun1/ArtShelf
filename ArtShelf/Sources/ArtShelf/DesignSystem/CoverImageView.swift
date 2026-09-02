import SwiftUI
import os

/// 封面图加载器：内存缓存 + 本地封面目录 + 远程下载回填
/// 下载按 URL 合并并发请求；主色按藏品 id 缓存。
enum CoverImageLoader {

    /// NSCache 本身线程安全；Swift 6 严格并发下以 nonisolated(unsafe) 显式声明共享
    nonisolated(unsafe) private static let memory: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 240            // 网格滚动场景的合理上限
        cache.totalCostLimit = 120 * 1024 * 1024   // 总量上限 120 MB（按像素 cost 计，见 cacheCost）
        return cache
    }()
    /// 内存缓存条目对应的封面标识（id → 封面来源）；封面编辑后旧图片按此失效（见 load）
    nonisolated(unsafe) private static var cachedIdentity: [UUID: String] = [:]
    /// 主色缓存（按藏品 id，避免网格滚动反复建 CIContext 重算 CIAreaAverage）
    nonisolated(unsafe) private static let dominantColors: NSCache<NSString, NSColor> = {
        let cache = NSCache<NSString, NSColor>()
        cache.countLimit = 256
        return cache
    }()
    /// 进行中的下载任务（按 URL 合并；Hero 环境层与主封面并发 miss 时只发一次请求）
    nonisolated(unsafe) private static var inflight: [URL: Task<Data?, Never>] = [:]
    /// 保护 inflight 与 cachedIdentity（NSCache 自身线程安全，字典不是）
    private static let stateLock = NSLock()
    private static let logger = Logger(subsystem: "ArtShelf", category: "CoverImageLoader")

    /// 封面标识：URL / 本地路径任一变化（编辑封面后）即视为新封面，
    /// 视图 task 重触发与内存缓存命中均以此为口径
    static func identity(for item: MediaItem) -> String {
        "\(item.coverURL ?? "")|\(item.localCoverPath ?? "")"
    }

    /// 加载封面：本地缓存文件 → 远程 URL 下载并回填到 covers 目录
    /// - Returns: (图片, 下载后回填的本地路径)。回填路径由调用方写入模型。
    static func load(for item: MediaItem) async -> (NSImage, String?)? {
        // 命中条件：图片在缓存中，且封面标识与当前一致（编辑封面后的旧图片视为失效）
        if let hit = cachedImage(for: item) { return (hit, nil) }

        // 本地文件
        if let path = item.localCoverPath,
           let image = NSImage(contentsOfFile: path) {
            cacheImage(image, for: item)
            return (image, nil)
        }

        // 远程下载（同一 URL 的并发请求共享一次网络传输）
        guard let urlString = item.coverURL, let url = URL(string: urlString) else { return nil }
        // 只放行 http/https，其他 scheme（如 file:// 指向本地任意路径）一律拒绝
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        guard let data = await inflightDownload(url).value,
              let image = NSImage(data: data) else { return nil }

        cacheImage(image, for: item)

        // 落盘回填：按数据魔数嗅探实际格式决定扩展名（旧 .jpg 文件不受影响）；
        // 并发调用方写同一路径，文件已存在则跳过，避免重复落盘。
        let path = LibraryPaths.coversDirectory
            .appendingPathComponent("\(item.id.uuidString).\(extensionFor(data))")
        if !FileManager.default.fileExists(atPath: path.path) {
            do {
                try data.write(to: path)
            } catch {
                // 写盘失败：图片照常显示，但不回填路径，避免模型指向不存在的文件
                logger.error("封面落盘失败: \(error, privacy: .public)")
                return (image, nil)
            }
        }
        return (image, path.path)
    }

    /// 写入内存缓存：按像素计 cost，并登记封面标识供下次命中校验
    private static func cacheImage(_ image: NSImage, for item: MediaItem) {
        let key = item.id.uuidString as NSString
        memory.setObject(image, forKey: key, cost: cacheCost(for: image))
        stateLock.lock()
        cachedIdentity[item.id] = identity(for: item)
        stateLock.unlock()
    }

    /// 命中检查（同步辅助：异步上下文禁止直接操作 NSLock）
    private static func cachedImage(for item: MediaItem) -> NSImage? {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard cachedIdentity[item.id] == identity(for: item) else { return nil }
        return memory.object(forKey: item.id.uuidString as NSString)
    }

    /// 移除某藏品的图片与主色缓存（删除藏品时调用方使用）
    static func evict(id: UUID) {
        let key = id.uuidString as NSString
        memory.removeObject(forKey: key)
        dominantColors.removeObject(forKey: key)
        stateLock.lock()
        cachedIdentity[id] = nil
        stateLock.unlock()
    }

    /// 封面主色（按藏品 id 缓存，供光晕 / 环境渲染使用）
    static func dominantColor(for id: UUID, image: NSImage) -> NSColor? {
        let key = id.uuidString as NSString
        if let hit = dominantColors.object(forKey: key) { return hit }
        guard let color = image.dominantColor() else { return nil }
        dominantColors.setObject(color, forKey: key)
        return color
    }

    /// 取（或创建）URL 对应的进行中下载任务
    private static func inflightDownload(_ url: URL) -> Task<Data?, Never> {
        stateLock.lock()
        defer { stateLock.unlock() }
        if let task = inflight[url] { return task }

        let task = Task<Data?, Never> {
            defer { removeInflight(url) }
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 8   // 与服务层超时口径一致（MetadataService 8s）
                // 豆瓣图床无 Referer 会返回 418（实测），需要声明来源页
                if url.host?.hasSuffix("doubanio.com") == true {
                    request.setValue("https://www.douban.com/", forHTTPHeaderField: "Referer")
                }
                let (data, _) = try await URLSession.shared.data(for: request)
                return data
            } catch {
                logger.error("封面下载失败: \(error, privacy: .public)")
                return nil
            }
        }
        inflight[url] = task
        return task
    }

    /// 下载结束清理进行中记录
    private static func removeInflight(_ url: URL) {
        stateLock.lock()
        inflight[url] = nil
        stateLock.unlock()
    }

    /// 缓存 cost：按位图像素数估算占用（RGBA 每像素 4 字节）；无位图表示时按 point 尺寸兜底
    private static func cacheCost(for image: NSImage) -> Int {
        let rep = image.representations.first
        let width = rep?.pixelsWide ?? Int(image.size.width)
        let height = rep?.pixelsHigh ?? Int(image.size.height)
        return max(1, width) * max(1, height) * 4
    }

    /// 按数据魔数嗅探图片格式，决定落盘扩展名（PNG / GIF，其余兜底 JPEG）
    private static func extensionFor(_ data: Data) -> String {
        let png: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        let gif: [UInt8] = [0x47, 0x49, 0x46, 0x38]
        if data.starts(with: png) { return "png" }
        if data.starts(with: gif) { return "gif" }
        return "jpg"   // JPEG（FF D8 FF）与未知格式兜底
    }
}

/// 封面视图：平铺封面（v3 取消拟物装帧），可选上报主色供光晕使用
struct CoverImageView: View {

    let item: MediaItem
    var cornerRadius: CGFloat = Theme.cardCorner
    /// 占位封面是否显示左下排版（环境色虚化层用无字版）
    var showsPlaceholderText: Bool = true
    var onDominantColor: ((Color?) -> Void)? = nil

    @Environment(LibraryStore.self) private var store
    @State private var image: NSImage?

    /// 占位封面（生成式渐变）
    private var generatedCover: GeneratedCoverView {
        GeneratedCoverView(title: item.title, creator: item.creator, year: yearText,
                           cornerRadius: 0, showsText: showsPlaceholderText)
    }

    /// 封面标识（藏品 id + URL + 本地路径）：切换藏品或编辑封面后即视为新封面，
    /// task 重触发与竞态守卫均以此为口径（与加载器缓存口径一致）
    private var coverIdentity: String {
        "\(item.id.uuidString)|" + CoverImageLoader.identity(for: item)
    }

    var body: some View {
        GeometryReader { geo in
            Group {
                if let image {
                    // 对齐概念稿：封面一律满幅裁切铺满画框（影视/书籍 2:3、音乐 1:1），不留白不垫模糊底
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    placeholder
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background(Theme.well)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .task(id: coverIdentity) { await load() }
    }

    private var placeholder: some View {
        generatedCover
    }

    private var yearText: String? {
        [item.creator, item.year.map(String.init)].compactMap { $0 }.isEmpty
            ? nil
            : [item.creator, item.year.map(String.init)].compactMap { $0 }.joined(separator: " · ")
    }

    private func load() async {
        let loadedID = item.id
        let loadedIdentity = coverIdentity
        // 重触发（切换藏品 / 封面变更）时先复位，避免短暂显示上一封面 / 旧光晕
        image = nil
        onDominantColor?(nil)

        guard let result = await CoverImageLoader.load(for: item) else {
            // 无封面可用：上报生成式封面的主色，光晕与环境渲染仍然成立
            guard !Task.isCancelled, loadedIdentity == coverIdentity else { return }
            onDominantColor?(generatedCover.dominantColor)
            return
        }
        let (loaded, backfillPath) = result
        // 异步返回后确认任务未被取消、封面标识仍与本次一致
        guard !Task.isCancelled, loadedIdentity == coverIdentity else { return }
        image = loaded
        // 下载成功的封面回填本地路径（原路径缺失才回填，守卫在 Store 内）
        if let backfillPath {
            store.backfillCover(id: loadedID, path: backfillPath)
        }
        if let onDominantColor {
            let color = await Task.detached(priority: .utility) {
                CoverImageLoader.dominantColor(for: loadedID, image: loaded)
            }.value
            guard !Task.isCancelled, loadedIdentity == coverIdentity else { return }
            onDominantColor(color.map(Color.init(nsColor:)))
        }
    }
}