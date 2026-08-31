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

    // MARK: - 解码

    private enum CodingKeys: String, CodingKey {
        case id, title, type
        case creator, year, synopsis, genre
        case coverURL, localCoverPath
        case rating, notes
        case tags, status, customSortOrder
        case localFilePath, webURL, appleMusicURL
        case dateAdded, lastViewedDate
        case albumName
    }

    /// 手写解码：旧版 JSON 缺省字段时回落默认值，避免整库解码失败
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        type = try container.decode(MediaType.self, forKey: .type)

        creator = try container.decodeIfPresent(String.self, forKey: .creator)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        synopsis = try container.decodeIfPresent(String.self, forKey: .synopsis)
        genre = try container.decodeIfPresent(String.self, forKey: .genre)

        coverURL = try container.decodeIfPresent(String.self, forKey: .coverURL)
        localCoverPath = try container.decodeIfPresent(String.self, forKey: .localCoverPath)

        rating = try container.decodeIfPresent(Int.self, forKey: .rating) ?? 0
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""

        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        status = try container.decodeIfPresent(MediaStatus.self, forKey: .status) ?? .planned
        customSortOrder = try container.decodeIfPresent(Int.self, forKey: .customSortOrder)

        localFilePath = try container.decodeIfPresent(String.self, forKey: .localFilePath)
        webURL = try container.decodeIfPresent(String.self, forKey: .webURL)
        appleMusicURL = try container.decodeIfPresent(String.self, forKey: .appleMusicURL)

        dateAdded = try container.decodeIfPresent(Date.self, forKey: .dateAdded) ?? Date()
        lastViewedDate = try container.decodeIfPresent(Date.self, forKey: .lastViewedDate)

        albumName = try container.decodeIfPresent(String.self, forKey: .albumName)
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
