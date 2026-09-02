import Foundation
import os

/// 库文件加载与 v2→v3 迁移
///
/// v3 与 v2 共用 `library.json`：v3 文档带 `schemaVersion: 3`。
/// `MediaItem` 的解码器已向下兼容 v2 字段（含 notes 字符串转手记），
/// 这里只负责版本甄别、备份与迁移默认值。
enum LibraryMigration {

    private static let logger = Logger(subsystem: "ArtShelf", category: "LibraryMigration")

    /// 当前线格式版本
    static let schemaVersion = 3

    // MARK: - 文档格式

    /// v3 库文档（存储与导出共用）
    struct LibraryDocument: Codable {
        var schemaVersion: Int = LibraryMigration.schemaVersion
        var exportedAt: Date = Date()
        var items: [MediaItem]
    }

    /// v2 包装格式（`{"items":…, "tagOrder":…}`）；v1 为纯数组
    private struct V2Wrapper: Codable {
        var items: [MediaItem]
    }

    /// 版本头探测（导入校验复用）
    struct HeaderProbe: Codable {
        var schemaVersion: Int?
    }

    enum LoadResult {
        case empty                // 无数据文件
        case loaded([MediaItem])  // v3 直接加载
        case migrated([MediaItem])// v2 → v3 迁移成功（调用方应立即落盘为新格式）
        case failed(String)       // 加载失败，值为给用户看的提示文案（损坏已备份 / 版本过新未动原文件）
    }

    // MARK: - 加载 / 迁移

    /// 从目录加载库；v2 文件自动迁移（先备份，绝不覆盖原始数据）
    static func load(from directory: URL) -> LoadResult {
        let file = directory.appendingPathComponent("library.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return .empty }

        do {
            let data = try Data(contentsOf: file)

            let probe = try? JSONDecoder().decode(HeaderProbe.self, from: data)

            // 前向兼容：schemaVersion 非 nil 且不等于当前值（如未来版本文件被旧版打开）时，
            // 旧版无法理解新版本专有字段——拒绝加载，绝不备份 / 迁移 / 写盘，
            // 避免新版本字段被静默丢弃覆盖
            if let version = probe?.schemaVersion, version != schemaVersion {
                logger.error("库文件由更新版本写入（schemaVersion \(version)），请升级应用后打开")
                return .failed("库文件由更新版本的 ArtShelf 写入。原文件未被改动，请升级应用后再打开。")
            }

            // v3：schemaVersion == 3
            if probe?.schemaVersion == schemaVersion {
                if let doc = try? JSONDecoder().decode(LibraryDocument.self, from: data) {
                    return .loaded(doc.items)
                }
                // 版本头为 v3 但内容无法解析：按损坏处理，不能落入 legacy 分支误生成 v2 备份
                backupCorrupt(file, in: directory)
                logger.error("v3 库文件内容无法解析，已备份损坏文件")
                return .failed("原始文件已备份在 ~/Library/Application Support/ArtShelf/ 中，当前以空库启动。")
            }

            // v2 包装格式 / v1 纯数组
            // 注：v2 条目的 `customSortOrder`（自定义排序）字段废弃不迁移——v3 设计无自定义排序
            let decoder = JSONDecoder()
            var legacy: [MediaItem]?
            if let wrapped = try? decoder.decode(V2Wrapper.self, from: data) {
                legacy = wrapped.items
            } else if let array = try? decoder.decode([MediaItem].self, from: data) {
                legacy = array
            }
            if let items = legacy {
                backupLegacy(file, in: directory)
                return .migrated(items.map(deriveMigrationDefaults))
            }

            // 无法解析：备份后启动空库，避免覆盖写丢失数据
            backupCorrupt(file, in: directory)
            logger.error("库文件无法解析，已备份损坏文件")
            return .failed("原始文件已备份在 ~/Library/Application Support/ArtShelf/ 中，当前以空库启动。")
        } catch {
            logger.error("读取库文件失败: \(error, privacy: .public)")
            return .failed("读取数据文件失败，当前以空库启动。原文件未被改动。")
        }
    }

    /// 迁移默认值：进行中藏品的最近品味时间回落到最近浏览 / 添加时间
    static func deriveMigrationDefaults(_ item: MediaItem) -> MediaItem {
        var item = item
        if item.status == .inProgress, item.lastTastedAt == nil {
            item.lastTastedAt = item.lastViewedDate ?? item.dateAdded
        }
        return item
    }

    // MARK: - 资料链接归位（常驻归一化）

    /// 已知资料站域名：语义拆分前这些链接被搜索预填进 webURL「观看链接」。
    /// 每次启动加载后统一归位（幂等——资料站域名永远不会是「观看链接」，
    /// 已归位或非资料站域名的条目自然跳过）；用户手动补的观看链接（YouTube / B 站等）不受影响
    private static let referenceDomains = ["douban.com", "wikipedia.org", "tvmaze.com", "itunes.apple.com"]

    private static func isReferenceHost(_ host: String) -> Bool {
        // books.google.com / books.google.co.jp 等多后缀域名单独按前缀判
        if host.hasPrefix("books.google.") { return true }
        // 严格域名边界：本身或子域名才算，避免误伤 notdouban.com 之类
        return referenceDomains.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    /// 把误置在 webURL 里的资料页链接搬回 referenceURL，返回是否有改动
    @discardableResult
    static func rehomeReferenceLinks(_ items: inout [MediaItem]) -> Bool {
        var changed = false
        for index in items.indices {
            guard items[index].referenceURL == nil,
                  let web = items[index].webURL,
                  let host = URL(string: web)?.host()?.lowercased(),
                  isReferenceHost(host)
            else { continue }
            items[index].referenceURL = web
            items[index].webURL = nil
            changed = true
        }
        return changed
    }

    // MARK: - 备份

    private static func backupLegacy(_ file: URL, in directory: URL) {
        let backup = directory.appendingPathComponent("library.v2.backup.json")
        guard !FileManager.default.fileExists(atPath: backup.path) else { return }
        try? FileManager.default.copyItem(at: file, to: backup)
    }

    private static func backupCorrupt(_ file: URL, in directory: URL) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let backup = directory.appendingPathComponent("library.json.corrupt-\(formatter.string(from: Date()))")
        try? FileManager.default.copyItem(at: file, to: backup)
    }
}
