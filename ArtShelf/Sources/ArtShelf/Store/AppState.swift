import SwiftUI

/// 一级导航（顶部 Tab），快捷键 ⌘1–⌘5
enum AppTab: Int, CaseIterable, Identifiable {
    case now = 1
    case movies
    case music
    case books
    case stats

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .now:    return "此刻"
        case .movies: return "片库"
        case .music:  return "唱片"
        case .books:  return "书架"
        case .stats:  return "统计"
        }
    }

    /// 对应的媒体类型（此刻 / 统计为 nil）
    var mediaType: MediaType? {
        switch self {
        case .movies: return .movie
        case .music:  return .music
        case .books:  return .book
        default:      return nil
        }
    }

    var keyEquivalent: KeyEquivalent {
        KeyEquivalent(Character("\(rawValue)"))
    }
}

/// 全局 UI 状态（导航 / 详情 / 收录弹窗 / 搜索）
@MainActor
@Observable
final class AppState {
    var tab: AppTab = .now
    /// 非 nil 时内容区整版显示详情页（按 id 引用，展示时从 LibraryStore 取最新值）
    var detailItemID: UUID?
    var showingAdd = false
    var searchText = ""
    /// ⌘F 聚焦搜索框的信号（自增即可）
    var searchFocusTick = 0

    func openDetail(_ item: MediaItem) {
        detailItemID = item.id
        searchText = ""
    }

    func closeDetail() {
        detailItemID = nil
    }
}
