import Foundation
import os
import SwiftUI

/// 磁盘存储的完整数据——包含收藏条目与标签自定义顺序
///
/// 兼容旧版：v1.4.0 之前只存 `[MediaItem]` 数组，load 时会自动迁移。
private struct LibraryData: Codable {
    var items: [MediaItem]
    var tagOrder: [String]?
}

/// 本地数据存储——所有数据以 JSON 形式存在 `~/Library/Application Support/ArtShelf/library.json`
final class DataStore: ObservableObject {

    @Published var items: [MediaItem] = [] {
        didSet { scheduleSave() }
    }

    /// 标签自定义顺序（用户拖拽后的顺序）。nil 或未收录的标签用字典序兜底。
    @Published var tagOrder: [String] = [] {
        didSet { scheduleSave() }
    }

    private var saveTimer: DispatchWorkItem?

    /// 统一日志出口
    private static let logger = Logger(subsystem: "ArtShelf", category: "DataStore")

    init() {
        load()
    }

    // MARK: - 持久化

    /// 从磁盘加载（兼容旧版纯数组格式）
    private func load() {
        let url = MediaItem.dataFile
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            // 优先新格式
            if let library = try? JSONDecoder().decode(LibraryData.self, from: data) {
                items = library.items
                tagOrder = library.tagOrder ?? []
            } else if let legacy = try? JSONDecoder().decode([MediaItem].self, from: data) {
                items = legacy
                tagOrder = []
            } else {
                // 两种格式都无法解析：先备份原始文件再启动空库，避免后续覆盖写丢失数据
                backupCorruptFile(at: url)
            }
        } catch {
            Self.logger.error("读取数据文件失败: \(error, privacy: .public)")
            backupCorruptFile(at: url)
        }
    }

    /// 将无法解析的数据文件原样复制为 `library.json.corrupt-<yyyyMMdd-HHmmss>`，防止空库覆盖写导致原始数据丢失
    private func backupCorruptFile(at url: URL) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let backupURL = url.deletingLastPathComponent()
            .appendingPathComponent("library.json.corrupt-\(formatter.string(from: Date()))")
        do {
            try FileManager.default.copyItem(at: url, to: backupURL)
            Self.logger.warning("数据文件无法解析，已备份到 \(backupURL.path, privacy: .public)")
        } catch {
            Self.logger.error("备份损坏数据失败: \(error, privacy: .public)")
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
            let library = LibraryData(items: items, tagOrder: tagOrder)
            let data = try JSONEncoder().encode(library)
            let url = MediaItem.dataFile
            try data.write(to: url, options: .atomic)
        } catch {
            Self.logger.error("保存数据失败: \(error, privacy: .public)")
        }
    }

    /// 立即同步保存——应用退出前调用（willTerminateNotification 触发），保证最后的修改落盘
    func flush() {
        saveNow()
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
        // 仅删除应用自管封面目录内的缓存文件；
        // 用户自选的图片（如 ~/Pictures）只解除引用，不删文件
        if let path = item.localCoverPath,
           URL(fileURLWithPath: path).standardizedFileURL.path.hasPrefix(MediaItem.coversDirectory.standardizedFileURL.path + "/") {
            try? FileManager.default.removeItem(atPath: path)
        }
        items.removeAll { $0.id == item.id }
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

    /// 获取某个类型的所有标签（去重，字典序）
    func tags(for type: MediaType) -> [String] {
        Set(items.filter { $0.type == type }.flatMap { $0.tags }).sorted()
    }

    /// 所有标签（去重，优先自定义顺序）
    var allTags: [String] {
        let all = Set(items.flatMap { $0.tags })
        // 自定义顺序中的标签保持用户排序；未在自定义列表中的按字典序追加
        let ordered = tagOrder.filter { all.contains($0) }
        let rest = all.subtracting(ordered).sorted()
        return ordered + rest
    }

    // MARK: - 标签排序

    /// 将标签移动到目标标签的位置（拖拽排序）
    ///
    /// 语义：拖到目标标签上 = 让被拖标签占据目标的位置——
    /// 被拖标签原本在目标上方则落到目标后面，原本在下方则插到目标前面。
    /// 这样无论往上还是往下拖动都有明确的位移效果。
    func moveTag(_ tag: String, before targetTag: String) {
        let current = allTags
        guard let from = current.firstIndex(of: tag),
              let to = current.firstIndex(of: targetTag),
              from != to else { return }

        var reordered = current
        reordered.remove(at: from)

        // 移除后目标的下标需要修正：被拖项在目标前面时，目标向左移一位
        let adjustedTarget = to > from ? to - 1 : to
        // 被拖项在目标前面（往下拖）→ 插到目标后面；
        // 被拖项在目标后面（往上拖）→ 插到目标前面。
        let insertIndex = to > from ? adjustedTarget + 1 : adjustedTarget
        reordered.insert(tag, at: insertIndex)

        // 只持久化当前存在的标签，清理失效项
        let all = Set(items.flatMap { $0.tags })
        tagOrder = reordered.filter { all.contains($0) }
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
            Self.logger.error("下载封面失败: \(error, privacy: .public)")
            return nil
        }
    }
}
