import Foundation
import SwiftUI

/// 时间筛选（已移除 planned——它是状态筛选，不是时间筛选）
enum TimeFilter: String, CaseIterable, Identifiable, Codable {
    case today   = "今天"
    case week    = "最近 7 天"
    case month   = "最近 30 天"
    case earlier = "更早"
    case all     = "全部"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .today:   return "sun.max.fill"
        case .week:    return "calendar"
        case .month:   return "calendar.badge.clock"
        case .earlier: return "tray.full"
        case .all:     return "square.grid.2x2.fill"
        }
    }
}

enum LibrarySortOption: String, CaseIterable, Identifiable {
    case smart = "智能排序"
    case recentlyViewed = "最近浏览"
    case newestAdded = "最近添加"
    case title = "标题"
    case rating = "评分"
    case custom = "自定义"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .smart: return "sparkles"
        case .recentlyViewed: return "clock.arrow.circlepath"
        case .newestAdded: return "calendar.badge.plus"
        case .title: return "textformat"
        case .rating: return "star.fill"
        case .custom: return "line.3.horizontal"
        }
    }
}

/// 应用导航状态
final class AppState: ObservableObject {

    /// 当前选中的媒体类型（nil = 全部）
    @Published var selectedCategory: MediaType? = nil

    /// 当前时间筛选
    @Published var selectedTimeFilter: TimeFilter = .all

    /// 当前选中的状态（nil = 不按状态筛选）
    @Published var selectedStatus: MediaStatus? = nil

    /// 当前选中的标签（nil = 不按标签筛选）
    @Published var selectedTag: String? = nil

    /// 当前选中的媒体项（用于详情页 sheet）
    @Published var detailItem: MediaItem? = nil

    /// 是否显示添加窗口
    @Published var showingAddSheet: Bool = false

    /// 是否显示偏好设置窗口
    @Published var showingSettingsSheet: Bool = false

    /// 搜索关键词
    @Published var searchText: String = ""

    /// 资料库排序方式
    @Published var selectedSort: LibrarySortOption = .smart

    /// 是否处于画廊主页视图（未选分类、未选标签、未搜索）
    var isHome: Bool {
        selectedCategory == nil && selectedTag == nil && searchText.isEmpty
    }

    func navigateToHome() {
        selectedCategory = nil
        selectedTag = nil
        searchText = ""
        clearBrowseFilters()
    }

    func navigateToCategory(_ type: MediaType) {
        selectedCategory = type
        selectedTag = nil
        clearBrowseFilters()
    }

    func clearBrowseFilters() {
        selectedStatus = nil
        selectedTimeFilter = .all
    }

    // MARK: - 过滤

    func filteredItems(from store: DataStore) -> [MediaItem] {
        store.items.filter { item in
            // 类型筛选
            if let cat = selectedCategory, item.type != cat { return false }

            // 标签筛选
            if let tag = selectedTag, !item.tags.contains(tag) { return false }

            // 状态筛选
            if let status = selectedStatus, item.status != status { return false }

            // 时间筛选
            switch selectedTimeFilter {
            case .today:
                if !item.viewedToday { return false }
            case .week:
                if !item.viewedWithin(days: 7) { return false }
            case .month:
                if !item.viewedWithin(days: 30) { return false }
            case .earlier:
                if item.lastViewedDate == nil || item.viewedWithin(days: 30) { return false }
            case .all:
                break
            }

            // 搜索
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                let match = item.title.lowercased().contains(q)
                    || (item.creator?.lowercased().contains(q) ?? false)
                    || (item.albumName?.lowercased().contains(q) ?? false)
                    || (item.synopsis?.lowercased().contains(q) ?? false)
                if !match { return false }
            }

            return true
        }
        .sorted(by: areInIncreasingOrder)
    }

    private func areInIncreasingOrder(_ lhs: MediaItem, _ rhs: MediaItem) -> Bool {
        switch selectedSort {
        case .smart:
            return smartSortKey(lhs) > smartSortKey(rhs)
        case .recentlyViewed:
            let left = lhs.lastViewedDate ?? .distantPast
            let right = rhs.lastViewedDate ?? .distantPast
            return left == right ? lhs.dateAdded > rhs.dateAdded : left > right
        case .newestAdded:
            return lhs.dateAdded > rhs.dateAdded
        case .title:
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        case .rating:
            return lhs.rating == rhs.rating ? lhs.dateAdded > rhs.dateAdded : lhs.rating > rhs.rating
        case .custom:
            let left = lhs.customSortOrder ?? Int.max
            let right = rhs.customSortOrder ?? Int.max
            return left == right ? lhs.dateAdded < rhs.dateAdded : left < right
        }
    }

    /// 排序键：在看的优先，其次最近浏览，最后添加日期
    private func smartSortKey(_ item: MediaItem) -> (Int, TimeInterval) {
        let statusPriority: Int
        switch item.status {
        case .inProgress: statusPriority = 2
        case .planned:    statusPriority = 1
        case .completed:  statusPriority = 0
        }
        let timeKey = item.lastViewedDate?.timeIntervalSince1970 ?? item.dateAdded.timeIntervalSince1970
        return (statusPriority, timeKey)
    }

    // MARK: - 状态标签

    /// 根据当前选中的媒体类型返回状态标签
    func statusLabel(for status: MediaStatus) -> String {
        if let category = selectedCategory {
            return status.label(for: category)
        }
        // 全部类型时，用通用标签
        switch status {
        case .planned:    return "待看 / 待听 / 待读"
        case .inProgress: return "在看 / 在听 / 在读"
        case .completed:  return "已看 / 已听 / 已读"
        }
    }

    func compactStatusLabel(for status: MediaStatus) -> String {
        if let category = selectedCategory {
            return status.label(for: category)
        }
        switch status {
        case .planned:    return "待开始"
        case .inProgress: return "进行中"
        case .completed:  return "已完成"
        }
    }
}
