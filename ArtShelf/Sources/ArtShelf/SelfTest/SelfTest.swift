// SelfTest.swift —— 内置自测（本机仅有 Command Line Tools，无 XCTest / Swift Testing，
// 故以 `--self-test` 启动参数运行数据层自测；仅 Debug 构建包含本文件）
#if DEBUG
import Foundation

/// 极简断言与套件入口
@MainActor
enum SelfTest {

    private static var checks = 0
    private static var failures = 0

    static func check(_ condition: Bool, _ name: String, _ detail: String = "") {
        checks += 1
        if !condition {
            failures += 1
            print("  ✗ \(name)" + (detail.isEmpty ? "" : " —— \(detail)"))
        }
    }

    static func checkEqual<T: Equatable>(_ actual: T, _ expected: T, _ name: String) {
        check(actual == expected, name, "期望 \(expected)，实际 \(actual)")
    }

    static func checkNil<T>(_ value: T?, _ name: String) {
        check(value == nil, name, "期望 nil，实际 \(String(describing: value))")
    }

    static func checkNotNil<T>(_ value: T?, _ name: String) {
        check(value != nil, name, "期望非 nil")
    }

    /// 运行全部套件，返回进程退出码（0 = 全绿）
    @MainActor
    static func run() -> Int32 {
        print("ArtShelf 自测（数据层）")
        migrationSuite()
        storeSuite()
        print("共 \(checks) 项断言，失败 \(failures) 项")
        return failures == 0 ? 0 : 1
    }

    // MARK: - 工具

    /// 建独立临时目录，块内使用，结束自动清理
    @MainActor
    private static func withTempDir(_ body: (URL) -> Void) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArtShelfSelfTest-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        body(dir)
    }

    private static func write(_ content: String, named name: String = "library.json", in dir: URL) {
        try! content.data(using: .utf8)!.write(to: dir.appendingPathComponent(name))
    }

    // MARK: - 库文件加载与 v2→v3 迁移

    @MainActor
    private static func migrationSuite() {
        print("[迁移]")

        withTempDir { dir in
            guard case .empty = LibraryMigration.load(from: dir) else {
                return check(false, "无文件应为 .empty")
            }
            check(true, "无文件应为 .empty")
        }

        withTempDir { dir in
            write("""
            {
              "schemaVersion": 3,
              "exportedAt": 700000000,
              "items": [
                { "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F", "title": "活着", "type": "书籍",
                  "status": "completed", "rating": 5, "progressCurrent": 191, "progressTotal": 191,
                  "notes": [{ "id": "A621E1F8-C36C-495A-93FC-0C247A3E6E5F", "createdAt": 700000000, "text": "读完沉默良久" }] }
              ]
            }
            """, in: dir)
            guard case .loaded(let items) = LibraryMigration.load(from: dir) else {
                return check(false, "v3 文档应为 .loaded")
            }
            checkEqual(items.count, 1, "v3 文档条目数")
            checkEqual(items[0].status, .completed, "v3 状态解析")
            checkEqual(items[0].progressCurrent, 191, "v3 进度解析")
            checkEqual(items[0].notes.first?.text, "读完沉默良久", "v3 手记解析")
        }

        withTempDir { dir in
            write("""
            {
              "items": [
                { "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F", "title": "花样年华", "type": "影视",
                  "status": "inProgress", "rating": 5, "notes": "  走廊里那盏灯  ",
                  "tags": ["港片"], "creator": "王家卫", "year": 2000,
                  "dateAdded": 700000000, "lastViewedDate": 700010000 }
              ],
              "tagOrder": ["港片"]
            }
            """, in: dir)
            guard case .migrated(let items) = LibraryMigration.load(from: dir) else {
                return check(false, "v2 包装格式应为 .migrated")
            }
            let item = items[0]
            checkEqual(item.title, "花样年华", "v2 标题")
            checkEqual(item.type, .movie, "v2 类型")
            checkEqual(item.status, .inProgress, "v2 状态")
            checkEqual(item.rating, 5, "v2 评分")
            checkEqual(item.tags, ["港片"], "v2 标签")
            checkEqual(item.progressCurrent, 0, "迁移后进度默认 0")
            checkEqual(item.replayCount, 0, "迁移后重温次数默认 0")
            checkEqual(item.notes.count, 1, "v2 单条笔记转为一条手记")
            checkEqual(item.notes[0].text, "走廊里那盏灯", "手记去除首尾空白")
            checkEqual(item.lastTastedAt, Date(timeIntervalSinceReferenceDate: 700010000),
                       "进行中藏品 lastTastedAt 回落到最近浏览时间")
            check(FileManager.default.fileExists(
                atPath: dir.appendingPathComponent("library.v2.backup.json").path),
                "迁移前备份原文件")
        }

        withTempDir { dir in
            write("""
            [
              { "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F", "title": "教父", "type": "影视" },
              { "id": "F621E1F8-C36C-495A-93FC-0C247A3E6E60", "title": "OK Computer", "type": "音乐" }
            ]
            """, in: dir)
            guard case .migrated(let items) = LibraryMigration.load(from: dir) else {
                return check(false, "v1 纯数组应为 .migrated")
            }
            checkEqual(items.count, 2, "v1 条目数")
            checkEqual(items[0].status, .planned, "v1 状态默认想品")
            checkEqual(items[0].rating, 0, "v1 评分默认 0")
            check(items[0].notes.isEmpty, "v1 无手记")
            checkNil(items[0].lastTastedAt, "v1 lastTastedAt 为 nil")
        }

        withTempDir { dir in
            write("not json at all", in: dir)
            guard case .failed = LibraryMigration.load(from: dir) else {
                return check(false, "损坏文件应为 .failed")
            }
            let contents = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
            check(contents.contains { $0.hasPrefix("library.json.corrupt-") }, "损坏文件已备份")
            let raw = try? String(contentsOf: dir.appendingPathComponent("library.json"), encoding: .utf8)
            checkEqual(raw, "not json at all", "原文件未被覆盖")
        }
    }

    // MARK: - 数据仓库与状态流转副作用（product-design.md §6）

    @MainActor
    private static func storeSuite() {
        print("[仓库]")

        // CRUD 与持久化
        withTempDir { dir in
            let store = LibraryStore(directory: dir)
            var item = MediaItem(title: "测试", type: .movie)
            store.add(item)
            checkEqual(store.items.count, 1, "收录后条目数")

            item.rating = 5
            store.update(item)
            checkEqual(store.item(for: item.id)?.rating, 5, "更新评分")

            store.delete(item)
            check(store.items.isEmpty, "删除后为空")
        }

        withTempDir { dir in
            let store = LibraryStore(directory: dir)
            let item = MediaItem(title: "测试", type: .movie)
            store.add(item)
            store.flush()

            // 同目录重新装配，应读回
            let reloaded = LibraryStore(directory: dir)
            checkEqual(reloaded.items.count, 1, "重载后条目数")
            checkEqual(reloaded.items.first?.id, item.id, "重载后 ID 一致")

            // 落盘为 v3 格式
            let raw = try? String(contentsOf: dir.appendingPathComponent("library.json"), encoding: .utf8)
            check(raw?.contains("\"schemaVersion\":3") == true
                  || raw?.contains("\"schemaVersion\" : 3") == true,
                  "落盘 schemaVersion 为 3")
        }

        // 状态流转
        withTempDir { dir in
            let store = LibraryStore(directory: dir)
            let item = MediaItem(title: "测试", type: .movie)
            store.add(item)
            checkNil(store.item(for: item.id)?.lastTastedAt, "收录时无品尝时间")
            store.startTasting(item)
            let updated = store.item(for: item.id)
            checkEqual(updated?.status, .inProgress, "开始品尝后进行中")
            checkNotNil(updated?.lastTastedAt, "开始品尝记录时间")
        }

        withTempDir { dir in
            let store = LibraryStore(directory: dir)
            var item = MediaItem(title: "测试", type: .movie)
            item.status = .inProgress
            store.add(item)
            store.updateProgress(item, current: 40, total: 100)
            store.finish(item)
            let updated = store.item(for: item.id)
            checkEqual(updated?.status, .completed, "品完后状态")
            checkEqual(updated?.progressCurrent, 100, "品完填满当前进度")
            checkEqual(updated?.progressTotal, 100, "品完保留总进度")
        }

        withTempDir { dir in
            let store = LibraryStore(directory: dir)
            var item = MediaItem(title: "测试", type: .movie)
            item.status = .completed
            store.add(item)
            store.updateProgress(item, current: 100, total: 100)
            store.replay(item)
            let updated = store.item(for: item.id)
            checkEqual(updated?.status, .inProgress, "重温后进行中")
            checkEqual(updated?.replayCount, 1, "重温计数 +1")
            checkEqual(updated?.progressCurrent, 0, "重温清空进度")
            checkNotNil(updated?.lastTastedAt, "重温记录时间")
        }

        withTempDir { dir in
            let store = LibraryStore(directory: dir)
            var item = MediaItem(title: "测试", type: .movie)
            item.status = .inProgress
            store.add(item)
            store.updateProgress(item, current: 100, total: 100)
            checkEqual(store.item(for: item.id)?.status, .completed, "进度填满自动品完")
        }

        withTempDir { dir in
            let store = LibraryStore(directory: dir)
            let item = MediaItem(title: "测试", type: .movie)
            store.add(item)
            store.updateProgress(item, current: 10, total: 100)
            checkEqual(store.item(for: item.id)?.status, .inProgress, "想品更新进度自动开始品尝")
        }

        // 进度比例钳制（纯模型计算）
        do {
            var item = MediaItem(title: "比例", type: .movie)
            checkEqual(item.progress, 0, "无总量时进度为 0")
            item.progressCurrent = 50
            item.progressTotal = 80
            check(abs(item.progress - 0.625) < 0.001, "进度比例 50/80")
            item.progressCurrent = 100
            checkEqual(item.progress, 1, "进度比例钳制到 1")
        }

        // 手记
        withTempDir { dir in
            let store = LibraryStore(directory: dir)
            let item = MediaItem(title: "测试", type: .movie)
            store.add(item)
            store.addNote(item, text: "第一条手记")
            var updated = store.item(for: item.id)
            checkEqual(updated?.notes.count, 1, "手记计数")
            checkEqual(updated?.sortedNotes.first?.text, "第一条手记", "手记内容")

            if let noteID = updated?.notes[0].id {
                store.deleteNote(item, noteID: noteID)
            }
            updated = store.item(for: item.id)
            check(updated?.notes.isEmpty == true, "删除手记")
        }

        // 封面回填
        withTempDir { dir in
            let store = LibraryStore(directory: dir)
            let item = MediaItem(title: "测试", type: .movie)
            store.add(item)
            store.backfillCover(id: item.id, path: "/tmp/cover-a.jpg")
            checkEqual(store.item(for: item.id)?.localCoverPath, "/tmp/cover-a.jpg", "封面回填")

            // 已有本地路径时不再覆盖
            store.backfillCover(id: item.id, path: "/tmp/cover-b.jpg")
            checkEqual(store.item(for: item.id)?.localCoverPath, "/tmp/cover-a.jpg", "封面只回填一次")
        }
    }
}
#endif
