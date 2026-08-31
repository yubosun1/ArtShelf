import Foundation
import AppKit
import os

/// JSON 导入导出 —— 线格式与存储格式同为 `LibraryDocument`（schemaVersion 3）
enum LibraryIO {

    private static let logger = Logger(subsystem: "ArtShelf", category: "LibraryIO")

    /// 导出全库为格式化 JSON（用户选路径）
    @MainActor
    static func exportLibrary(store: LibraryStore) {
        do {
            let doc = LibraryMigration.LibraryDocument(items: store.items)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(doc)

            let panel = NSSavePanel()
            panel.nameFieldStringValue = "ArtShelf-library.json"
            panel.allowedContentTypes = [.json]
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error("导出失败: \(error, privacy: .public)")
        }
    }

    /// 从 JSON 导入（跳过已存在的 id）。返回导入条数。
    @MainActor
    @discardableResult
    static func importLibrary(store: LibraryStore) -> Int {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return 0 }

        do {
            let data = try Data(contentsOf: url)
            let doc = try JSONDecoder().decode(LibraryMigration.LibraryDocument.self, from: data)
            let existing = Set(store.items.map(\.id))
            var count = 0
            for item in doc.items where !existing.contains(item.id) {
                store.add(item)
                count += 1
            }
            store.flush()
            return count
        } catch {
            logger.error("导入失败: \(error, privacy: .public)")
            return 0
        }
    }
}
