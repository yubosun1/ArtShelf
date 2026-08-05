import Foundation
import SwiftUI

/// 本地数据存储——所有数据以 JSON 形式存在 `~/Library/Application Support/ArtShelf/library.json`
final class DataStore: ObservableObject {

    @Published var items: [MediaItem] = [] {
        didSet { scheduleSave() }
    }

    private var saveTimer: DispatchWorkItem?

    init() {
        load()
    }

    // MARK: - 持久化

    /// 从磁盘加载
    private func load() {
        let url = MediaItem.dataFile
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            items = try JSONDecoder().decode([MediaItem].self, from: data)
        } catch {
            print("⚠️ 加载数据失败: \(error)")
        }
    }

    /// 防抖保存（避免频繁写入磁盘）
    private func scheduleSave() {
        saveTimer?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.saveNow()
        }
        saveTimer = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)
    }

    private func saveNow() {
        do {
            let data = try JSONEncoder().encode(items)
            let url = MediaItem.dataFile
            try data.write(to: url, options: .atomic)
        } catch {
            print("⚠️ 保存数据失败: \(error)")
        }
    }

    // MARK: - CRUD

    func add(_ item: MediaItem) {
        var newItem = item
        if newItem.customSortOrder == nil {
            newItem.customSortOrder = (items.compactMap(\.customSortOrder).max() ?? -1) + 1
        }
        items.append(newItem)
    }

    func update(_ item: MediaItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx] = item
    }

    func delete(_ item: MediaItem) {
        // 清理本地封面文件
        if let path = item.localCoverPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        items.removeAll { $0.id == item.id }
    }

    func delete(id: UUID) {
        items.removeAll { $0.id == id }
    }

    func item(for id: UUID) -> MediaItem? {
        items.first { $0.id == id }
    }

    // MARK: - 自定义排序

    func prepareCustomOrder(from visibleItems: [MediaItem]) {
        let visibleIDs = Set(visibleItems.map(\.id))
        let remainder = items.filter { !visibleIDs.contains($0.id) }
        applyCustomOrder(visibleItems + remainder)
    }

    func moveCustomItem(id: UUID, before targetID: UUID) {
        var ordered = items.sorted {
            let left = $0.customSortOrder ?? Int.max
            let right = $1.customSortOrder ?? Int.max
            return left == right ? $0.dateAdded < $1.dateAdded : left < right
        }
        guard let sourceIndex = ordered.firstIndex(where: { $0.id == id }),
              let originalTargetIndex = ordered.firstIndex(where: { $0.id == targetID }),
              sourceIndex != originalTargetIndex else { return }

        let moving = ordered.remove(at: sourceIndex)
        let targetIndex = ordered.firstIndex(where: { $0.id == targetID }) ?? originalTargetIndex
        ordered.insert(moving, at: targetIndex)
        applyCustomOrder(ordered)
    }

    private func applyCustomOrder(_ ordered: [MediaItem]) {
        let positions = Dictionary(uniqueKeysWithValues: ordered.enumerated().map { ($0.element.id, $0.offset) })
        for index in items.indices {
            items[index].customSortOrder = positions[items[index].id]
        }
    }

    /// 获取某个类型的所有标签（去重）
    func tags(for type: MediaType) -> [String] {
        Set(items.filter { $0.type == type }.flatMap { $0.tags }).sorted()
    }

    /// 所有标签（去重）
    var allTags: [String] {
        Set(items.flatMap { $0.tags }).sorted()
    }

    // MARK: - 封面缓存

    /// 将远程封面下载到本地缓存
    func cacheCover(for item: MediaItem, from urlString: String) async -> String? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let path = MediaItem.coversDirectory.appendingPathComponent("\(item.id.uuidString).jpg")
            try data.write(to: path)
            return path.path
        } catch {
            print("⚠️ 下载封面失败: \(error)")
            return nil
        }
    }
}
