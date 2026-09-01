import Foundation
import AppKit
import os

/// JSON 导入导出 —— 线格式与存储格式同为 `LibraryDocument`（schemaVersion 3）
enum LibraryIO {

    private static let logger = Logger(subsystem: "ArtShelf", category: "LibraryIO")

    /// 导出结果
    enum ExportResult {
        case exported(URL)   // 导出到的文件路径
        case cancelled       // 用户取消
        case failed(String)  // 失败原因（供 UI 提示）
    }

    /// 导入结果
    enum ImportResult {
        case imported(Int)   // 实际导入条数（已跳过重复 id）
        case cancelled       // 用户取消
        case failed(String)  // 失败原因（供 UI 提示）
    }

    /// 导入解析错误
    enum ImportError: Error {
        case unsupportedVersion   // 不是当前线格式
        case unreadable(String)   // 内容无法解析

        var message: String {
            switch self {
            case .unsupportedVersion:
                return "文件不是 schemaVersion \(LibraryMigration.schemaVersion) 的 ArtShelf 库"
            case .unreadable(let detail):
                return detail
            }
        }
    }

    /// 导出全库为格式化 JSON（用户选路径）
    @MainActor
    @discardableResult
    static func exportLibrary(store: LibraryStore) -> ExportResult {
        do {
            let doc = LibraryMigration.LibraryDocument(items: store.items)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(doc)

            let panel = NSSavePanel()
            panel.nameFieldStringValue = "ArtShelf-library.json"
            panel.allowedContentTypes = [.json]
            guard panel.runModal() == .OK, let url = panel.url else { return .cancelled }
            try data.write(to: url, options: .atomic)
            return .exported(url)
        } catch {
            logger.error("导出失败: \(error, privacy: .public)")
            return .failed(error.localizedDescription)
        }
    }

    /// 从 JSON 导入（用户选路径）
    @MainActor
    @discardableResult
    static func importLibrary(store: LibraryStore) -> ImportResult {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return .cancelled }

        do {
            let data = try Data(contentsOf: url)
            let items = try parseImport(data, existingIDs: Set(store.items.map(\.id)))
            items.forEach { store.add($0) }
            store.flush()
            return .imported(items.count)
        } catch let error as ImportError {
            logger.error("导入失败: \(error.message, privacy: .public)")
            return .failed(error.message)
        } catch {
            logger.error("导入失败: \(error, privacy: .public)")
            return .failed(error.localizedDescription)
        }
    }

    /// 解析导入 JSON：先探版本头只接受当前线格式，再解码；
    /// 跳过库内已有与文件内重复的 id，进行中条目的最近品味时间按迁移器口径回填。
    /// 与文件面板解耦，便于自测。
    static func parseImport(_ data: Data, existingIDs: Set<UUID>) throws -> [MediaItem] {
        guard let probe = try? JSONDecoder().decode(LibraryMigration.HeaderProbe.self, from: data),
              probe.schemaVersion == LibraryMigration.schemaVersion else {
            throw ImportError.unsupportedVersion
        }
        do {
            let doc = try JSONDecoder().decode(LibraryMigration.LibraryDocument.self, from: data)
            var seen = existingIDs
            var items: [MediaItem] = []
            for item in doc.items where seen.insert(item.id).inserted {
                items.append(LibraryMigration.deriveMigrationDefaults(item))
            }
            return items
        } catch {
            throw ImportError.unreadable(error.localizedDescription)
        }
    }
}
