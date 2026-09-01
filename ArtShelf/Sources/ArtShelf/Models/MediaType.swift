import Foundation

/// 三大媒体类型：影视、音乐、书籍
///
/// rawValue 与 v2 JSON 线格式一致（"影视"/"音乐"/"书籍"），保证旧数据可直接解码。
enum MediaType: String, Codable, CaseIterable, Identifiable, Sendable {
    case movie = "影视"
    case music = "音乐"
    case book  = "书籍"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .movie: return "film"
        case .music: return "opticaldisc"
        case .book:  return "book.closed"
        }
    }

    /// 界面名（与顶部 Tab 名称一致）：片库 / 唱片 / 书架
    var tabTitle: String {
        switch self {
        case .movie: return "片库"
        case .music: return "唱片"
        case .book:  return "书架"
        }
    }

    // MARK: - 状态文案

    var plannedLabel: String {
        switch self {
        case .movie: return "待看"
        case .music: return "待听"
        case .book:  return "待读"
        }
    }
    var inProgressLabel: String {
        switch self {
        case .movie: return "在看"
        case .music: return "在听"
        case .book:  return "在读"
        }
    }
    var completedLabel: String {
        switch self {
        case .movie: return "已看"
        case .music: return "已听"
        case .book:  return "已读"
        }
    }

    /// 「继续品味」动作文案
    var continueLabel: String {
        switch self {
        case .movie: return "继续观赏"
        case .music: return "继续聆听"
        case .book:  return "继续阅读"
        }
    }

    /// 封面宽高比 (width / height)
    var coverAspectRatio: Double {
        switch self {
        case .music: return 1.0          // 方形专辑封面
        default:     return 2.0 / 3.0    // 海报 / 书籍封面
        }
    }

    /// 进度单位名称（分钟 / 页 / 轨）
    var progressUnit: String {
        switch self {
        case .movie: return "分钟"
        case .music: return "轨"
        case .book:  return "页"
        }
    }

    /// 详情页进度步进幅度（±10 分钟 / ±10 页 / ±1 轨）
    var progressStep: Int {
        switch self {
        case .music: return 1
        default:     return 10
        }
    }

    /// 进度描述，如「61 分钟 / 98 分钟」「第 3 / 12 轨」「P.128 / 256」
    /// current 超过 total 时（总量被改小）按 total 钳制展示；存储值不动，总量改回即恢复真实进度
    func progressText(current: Int, total: Int) -> String {
        let shown = total > 0 ? min(current, total) : current
        switch self {
        case .movie: return "\(shown) 分钟 / \(total) 分钟"
        case .music: return "第 \(shown) / \(total) 轨"
        case .book:  return "P.\(shown) / \(total)"
        }
    }
}
