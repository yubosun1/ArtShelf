import Foundation

/// 一条媒体记录——电影/电视剧、专辑、书籍
struct MediaItem: Identifiable, Codable, Hashable {

    let id: UUID

    var title: String
    var type: MediaType

    // 元数据
    var creator: String?          // 导演 / 艺术家 / 作者
    var year: Int?
    var synopsis: String?         // 简介
    var genre: String?

    // 封面
    var coverURL: String?         // 远程封面 URL
    var localCoverPath: String?   // 本地缓存的封面文件路径

    // 用户评价
    var rating: Int = 0            // 0-5 星
    var notes: String = ""         // 个人感想 / 评价

    // 分类与管理
    var tags: [String] = []
    var status: MediaStatus = .planned
    var customSortOrder: Int?

    // 文件关联
    var localFilePath: String?     // 本地文件路径
    var webURL: String?            // 在线观看 / 收听 / 阅读链接
    var appleMusicURL: String?     // Apple Music 专辑链接

    // 时间
    var dateAdded: Date = Date()
    var lastViewedDate: Date?

    // 音乐专用
    var albumName: String?

    init(title: String, type: MediaType) {
        self.id = UUID()
        self.title = title
        self.type = type
    }

    // MARK: - 便捷方法

    /// 是否在今天浏览过
    var viewedToday: Bool {
        guard let date = lastViewedDate else { return false }
        return Calendar.current.isDateInToday(date)
    }

    /// 是否在最近 N 天内浏览过
    func viewedWithin(days: Int) -> Bool {
        guard let date = lastViewedDate else { return false }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return date > cutoff
    }

    /// 封面缓存目录
    static var coversDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ArtShelf/covers", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 数据文件路径
    static var dataFile: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ArtShelf", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("library.json")
    }
}
