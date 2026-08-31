import Foundation
import os

/// 馆藏数据仓库：内存全量 + JSON 防抖落盘
///
/// 单一事实来源。视图层不直接改 `status` / `progressCurrent` 等字段，
/// 一律经由这里的方法执行，保证流转副作用（见 docs/product-design.md §6）一致。
@MainActor
@Observable
final class LibraryStore {

    static let shared = LibraryStore()

    private static let logger = Logger(subsystem: "ArtShelf", category: "LibraryStore")

    /// 全部藏品（只读；修改一律走本类方法）
    private(set) var items: [MediaItem] = []

    /// 数据文件无法解析（已备份损坏文件），供 UI 提示
    private(set) var loadFailed = false

    @ObservationIgnored private let directory: URL
    @ObservationIgnored private var saveWorkItem: DispatchWorkItem?

    /// 默认用应用数据目录；测试可注入临时目录
    init(directory: URL = LibraryPaths.appDirectory) {
        self.directory = directory
        load()
    }

    // MARK: - 持久化

    private var dataFile: URL {
        directory.appendingPathComponent("library.json")
    }

    private func load() {
        switch LibraryMigration.load(from: directory) {
        case .empty:
            break
        case .loaded(let items):
            self.items = items
        case .migrated(let items):
            self.items = items
            saveNow()   // 立即落盘为 v3 格式
            Self.logger.info("v2→v3 迁移完成，共 \(items.count) 条")
        case .failed:
            loadFailed = true
        }
    }

    /// 防抖保存（0.5s）
    private func scheduleSave() {
        saveWorkItem?.cancel()
        let task = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWorkItem = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)
    }

    private func saveNow() {
        do {
            let doc = LibraryMigration.LibraryDocument(items: items)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(doc)
            try data.write(to: dataFile, options: .atomic)
        } catch {
            Self.logger.error("保存数据失败: \(error, privacy: .public)")
        }
    }

    /// 立即同步落盘——应用退出前调用
    func flush() {
        saveWorkItem?.cancel()
        saveNow()
    }

    // MARK: - 收录 / 更新 / 删除

    func add(_ item: MediaItem) {
        items.append(item)
        scheduleSave()
    }

    /// 整体替换一条藏品（评分 / 标签等直接编辑的落点）
    func update(_ item: MediaItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx] = item
        scheduleSave()
    }

    /// 删除藏品；应用自管封面目录内的缓存文件一并清理，
    /// 用户自选图片（如 ~/Pictures）只解除引用不删文件
    func delete(_ item: MediaItem) {
        if let path = item.localCoverPath,
           URL(fileURLWithPath: path).standardizedFileURL.path
               .hasPrefix(LibraryPaths.coversDirectory.standardizedFileURL.path + "/") {
            try? FileManager.default.removeItem(atPath: path)
        }
        items.removeAll { $0.id == item.id }
        scheduleSave()
    }

    func item(for id: UUID) -> MediaItem? {
        items.first { $0.id == id }
    }

    // MARK: - 状态流转（自动副作用见 product-design.md §6）

    /// 待品味 → 进行中：记录最近品味时间
    func startTasting(_ item: MediaItem) {
        mutate(item) { $0.status = .inProgress; $0.lastTastedAt = Date() }
    }

    /// 任意 → 已完成：进度自动补满
    func finish(_ item: MediaItem) {
        mutate(item) {
            $0.status = .completed
            if $0.progressTotal > 0 { $0.progressCurrent = $0.progressTotal }
            $0.lastTastedAt = Date()
        }
    }

    /// 再看一遍：状态 → 进行中，重温 +1，进度清零
    func replay(_ item: MediaItem) {
        mutate(item) {
            $0.status = .inProgress
            $0.replayCount += 1
            $0.progressCurrent = 0
            $0.lastTastedAt = Date()
        }
    }

    /// 更新进度；置满时自动流转为已完成，从 0 开始时自动转入进行中
    func updateProgress(_ item: MediaItem, current: Int, total: Int? = nil) {
        mutate(item) { i in
            if let total { i.progressTotal = max(0, total) }
            let cap = i.progressTotal
            i.progressCurrent = max(0, cap > 0 ? min(current, cap) : current)
            i.lastTastedAt = Date()
            if cap > 0 && i.progressCurrent >= cap {
                i.status = .completed
            } else if i.status == .planned && i.progressCurrent > 0 {
                i.status = .inProgress
            }
        }
    }

    func setStatus(_ item: MediaItem, _ status: MediaStatus) {
        switch status {
        case .inProgress: startTasting(item)
        case .completed:  finish(item)
        case .planned:    mutate(item) { $0.status = .planned }
        }
    }

    // MARK: - 手记

    func addNote(_ item: MediaItem, text: String) {
        mutate(item) { $0.notes.append(NoteEntry(text: text)) }
    }

    func deleteNote(_ item: MediaItem, noteID: UUID) {
        mutate(item) { $0.notes.removeAll { $0.id == noteID } }
    }

    // MARK: - 浏览 / 封面回填

    func markViewed(_ item: MediaItem) {
        mutate(item) { $0.lastViewedDate = Date() }
    }

    /// 封面下载成功后回填本地缓存路径
    func backfillCover(id: UUID, path: String) {
        guard let item = item(for: id), item.localCoverPath == nil else { return }
        mutate(item) { $0.localCoverPath = path }
    }

    // MARK: - 内部

    private func mutate(_ item: MediaItem, _ change: (inout MediaItem) -> Void) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        change(&items[idx])
        scheduleSave()
    }
}
