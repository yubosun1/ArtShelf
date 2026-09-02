import Foundation

/// 馆藏统计派生口径——「此刻」数据条与「统计」页共用，改一处全局生效
///（口径约束见 docs/product-design.md §4.5：一律从现有字段直接派生）
enum LibraryStats {
    /// 本月新增件数
    static func addedThisMonth(_ items: [MediaItem]) -> Int {
        let cal = Calendar.current
        return items.filter { cal.isDate($0.dateAdded, equalTo: Date(), toGranularity: .month) }.count
    }

    /// 策展手记总数
    static func noteCount(_ items: [MediaItem]) -> Int {
        items.reduce(0) { $0 + $1.notes.count }
    }

    /// 平均评分（仅统计已评分条目；无已评分条目为 nil）
    static func averageRating(_ items: [MediaItem]) -> Double? {
        let rated = items.filter { $0.rating > 0 }
        guard !rated.isEmpty else { return nil }
        return Double(rated.reduce(0) { $0 + $1.rating }) / Double(rated.count)
    }
}