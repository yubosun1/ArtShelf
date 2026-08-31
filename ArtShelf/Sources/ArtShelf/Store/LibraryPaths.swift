import Foundation

/// 本地存储路径约定
///
/// 一切用户数据只存于 `~/Library/Application Support/ArtShelf/`。
enum LibraryPaths {

    /// 应用数据目录
    static var appDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ArtShelf", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 封面缓存目录（沿用 v2 约定）
    static var coversDirectory: URL {
        let dir = appDirectory.appendingPathComponent("covers", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 数据文件（v3 起为带 schemaVersion 的 JSON 文档）
    static var dataFile: URL {
        appDirectory.appendingPathComponent("library.json")
    }

    /// v2 数据迁移前的备份文件
    static var legacyBackupFile: URL {
        appDirectory.appendingPathComponent("library.v2.backup.json")
    }
}
