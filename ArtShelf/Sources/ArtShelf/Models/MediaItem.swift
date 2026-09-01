import Foundation

/// 一条藏品记录 —— 影视 / 音乐 / 书籍（Codable 值类型，JSON 本地存储）
///
/// 解码器向下兼容 v2 线格式：缺失字段回落默认值，`notes` 字符串自动转为手记条目。
struct MediaItem: Identifiable, Codable, Hashable, Sendable {

    var id: UUID
    var title: String
    var type: MediaType

    // 元数据
    var creator: String?          // 导演 / 艺术家 / 作者
    var year: Int?
    var synopsis: String?         // 简介
    var genre: String?

    // 封面
    var coverURL: String?         // 远程封面 URL
    var localCoverPath: String?   // 本地缓存封面文件路径

    // 用户评价
    var rating: Int = 0           // 0-5 星

    // 分类与管理
    var tags: [String] = []
    var status: MediaStatus = .planned

    // 文件关联
    var localFilePath: String?    // 本地文件路径
    var webURL: String?           // 在线观看 / 收听 / 阅读链接（用户手动补充）
    var referenceURL: String?     // 资料链接（豆瓣 / 维基百科，搜索预填，仅供查阅）
    var appleMusicURL: String?    // Apple Music 专辑链接

    // 音乐专用
    var albumName: String?

    // 时间
    var dateAdded: Date = Date()
    var lastViewedDate: Date?
    var lastTastedAt: Date?       // 最近品味时间——驱动「此刻」排序

    // 进度（影视=分钟 / 书籍=页 / 音乐=音轨）
    var progressCurrent: Int = 0
    var progressTotal: Int = 0
    /// 影视进度单位：nil=分钟（默认电影），可选集 / 期（剧集、综艺）；仅对 .movie 生效
    var progressUnit: ProgressUnit?

    /// 重温次数（「再看一遍」流转累加）
    var replayCount: Int = 0

    /// 策展手记（条目化，按时间倒序展示）
    var notes: [NoteEntry] = []

    init(title: String, type: MediaType) {
        self.id = UUID()
        self.title = title
        self.type = type
    }

    // MARK: - 解码（v2 / 缺省字段容错）

    private enum CodingKeys: String, CodingKey {
        case id, title, type
        case creator, year, synopsis, genre
        case coverURL, localCoverPath
        case rating, tags, status
        case localFilePath, webURL, referenceURL, appleMusicURL, albumName
        case dateAdded, lastViewedDate, lastTastedAt
        case progressCurrent, progressTotal, progressUnit, replayCount
        case notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        // 未知枚举值落默认值，避免单条脏数据拖垮整库解码
        type = (try? c.decode(MediaType.self, forKey: .type)) ?? .movie
        creator = try c.decodeIfPresent(String.self, forKey: .creator)
        year = try c.decodeIfPresent(Int.self, forKey: .year)
        synopsis = try c.decodeIfPresent(String.self, forKey: .synopsis)
        genre = try c.decodeIfPresent(String.self, forKey: .genre)
        coverURL = try c.decodeIfPresent(String.self, forKey: .coverURL)
        localCoverPath = try c.decodeIfPresent(String.self, forKey: .localCoverPath)
        rating = try c.decodeIfPresent(Int.self, forKey: .rating) ?? 0
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        status = (try? c.decode(MediaStatus.self, forKey: .status)) ?? .planned
        localFilePath = try c.decodeIfPresent(String.self, forKey: .localFilePath)
        webURL = try c.decodeIfPresent(String.self, forKey: .webURL)
        referenceURL = try c.decodeIfPresent(String.self, forKey: .referenceURL)
        appleMusicURL = try c.decodeIfPresent(String.self, forKey: .appleMusicURL)
        albumName = try c.decodeIfPresent(String.self, forKey: .albumName)
        dateAdded = try c.decodeIfPresent(Date.self, forKey: .dateAdded) ?? Date()
        lastViewedDate = try c.decodeIfPresent(Date.self, forKey: .lastViewedDate)
        lastTastedAt = try c.decodeIfPresent(Date.self, forKey: .lastTastedAt)
        progressCurrent = try c.decodeIfPresent(Int.self, forKey: .progressCurrent) ?? 0
        progressTotal = try c.decodeIfPresent(Int.self, forKey: .progressTotal) ?? 0
        progressUnit = try? c.decode(ProgressUnit.self, forKey: .progressUnit)
        replayCount = try c.decodeIfPresent(Int.self, forKey: .replayCount) ?? 0

        // v3 手记数组；v2 为单条字符串——自动转为一条手记
        if let entries = try? c.decode([NoteEntry].self, forKey: .notes) {
            notes = entries
        } else if let legacy = try c.decodeIfPresent(String.self, forKey: .notes) {
            let text = legacy.trimmingCharacters(in: .whitespacesAndNewlines)
            notes = text.isEmpty ? [] : [NoteEntry(text: text, createdAt: lastViewedDate ?? dateAdded)]
        } else {
            notes = []
        }
    }

    // MARK: - 派生

    /// 进度 0–1（无总量信息时为 0）
    var progress: Double {
        guard progressTotal > 0 else { return 0 }
        return min(1, max(0, Double(progressCurrent) / Double(progressTotal)))
    }

    /// 进度描述文案（影视按所选单位：分钟 / 集 / 期）
    var progressText: String {
        let shown = progressTotal > 0 ? min(progressCurrent, progressTotal) : progressCurrent
        switch (type, progressUnit) {
        case (.movie, .episodes?): return "第 \(shown) / \(progressTotal) 集"
        case (.movie, .issues?):   return "第 \(shown) / \(progressTotal) 期"
        default: return type.progressText(current: progressCurrent, total: progressTotal)
        }
    }

    /// 进度单位文案（影视可选分钟 / 集 / 期，其余类型按类型默认）
    var progressUnitLabel: String {
        if type == .movie, let progressUnit { return progressUnit.label }
        return type.progressUnit
    }

    /// 详情页进度步进幅度（分钟 ±10；集 / 期 ±1）
    var progressStep: Int {
        if type == .movie, let progressUnit { return progressUnit.step }
        return type.progressStep
    }

    /// 笔记按时间倒序
    var sortedNotes: [NoteEntry] {
        notes.sorted { $0.createdAt > $1.createdAt }
    }

    /// 最新一条手记（Hero 摘要用）
    var latestNote: NoteEntry? { sortedNotes.first }

    /// 状态文案
    var statusLabel: String { status.label(for: type) }
}

/// 影视进度单位：分钟（电影）/ 集（剧集）/ 期（综艺）
enum ProgressUnit: String, Codable, CaseIterable, Sendable {
    case minutes
    case episodes
    case issues

    var label: String {
        switch self {
        case .minutes:  return "分钟"
        case .episodes: return "集"
        case .issues:   return "期"
        }
    }

    /// 详情页步进幅度：分钟 ±10，集 / 期 ±1
    var step: Int { self == .minutes ? 10 : 1 }
}
