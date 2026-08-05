import SwiftUI

/// 三大媒体类型：影视、音乐、书籍
enum MediaType: String, Codable, CaseIterable, Identifiable {
    case movie = "影视"
    case music = "音乐"
    case book = "书籍"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .movie: return "film"
        case .music: return "opticaldisc"
        case .book:  return "book.closed"
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

    /// 封面宽高比 (width / height)
    var coverAspectRatio: CGFloat {
        switch self {
        case .music: return 1.0          // 方形专辑封面
        default:     return 2.0 / 3.0    // 海报 / 书籍封面
        }
    }
}
