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
        ioSuite()
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

        withTempDir { dir in
            // 版本头为 v3 但内容无法解析：按损坏处理，不得落入 v2 迁移分支
            write("""
            { "schemaVersion": 3, "items": "oops" }
            """, in: dir)
            guard case .failed = LibraryMigration.load(from: dir) else {
                return check(false, "v3 头 + 坏内容应为 .failed")
            }
            let contents = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
            check(contents.contains { $0.hasPrefix("library.json.corrupt-") }, "v3 坏内容备份为 corrupt")
            check(!contents.contains("library.v2.backup.json"), "v3 坏内容不生成 v2 备份")
        }

        withTempDir { dir in
            // 前向兼容：未来版本（schemaVersion 4）文件被旧版打开——拒绝加载，不备份、不写盘
            let future = """
            {
              "schemaVersion": 4,
              "exportedAt": 700000000,
              "items": [
                { "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F", "title": "未来版本条目", "type": "影视" }
              ]
            }
            """
            write(future, in: dir)
            guard case .failed = LibraryMigration.load(from: dir) else {
                return check(false, "schemaVersion 4 应为 .failed")
            }
            let contents = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
            checkEqual(contents.count, 1, "高版本文件不产生任何备份")
            let raw = try? String(contentsOf: dir.appendingPathComponent("library.json"), encoding: .utf8)
            checkEqual(raw, future, "高版本原文件未被改动")
        }

        withTempDir { dir in
            // 未知枚举值落默认值，不拖垮整库解码
            write("""
            {
              "schemaVersion": 3,
              "exportedAt": 700000000,
              "items": [
                { "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F", "title": "脏数据", "type": "游戏", "status": "归档" },
                { "id": "F621E1F8-C36C-495A-93FC-0C247A3E6E60", "title": "正常", "type": "音乐", "status": "completed" }
              ]
            }
            """, in: dir)
            guard case .loaded(let items) = LibraryMigration.load(from: dir) else {
                return check(false, "含未知枚举的 v3 文档应仍可加载")
            }
            checkEqual(items.count, 2, "未知枚举不丢条目")
            checkEqual(items[0].type, .movie, "未知类型回落默认影视")
            checkEqual(items[0].status, .planned, "未知状态回落待品味")
            checkEqual(items[1].type, .music, "已知类型正常解析")
        }

        withTempDir { dir in
            // referenceURL / progressUnit 新字段解析；旧数据缺字段或未知单位值均容错为 nil
            write("""
            {
              "schemaVersion": 3,
              "exportedAt": 700000000,
              "items": [
                { "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F", "title": "大明王朝1566", "type": "影视",
                  "referenceURL": "https://movie.douban.com/subject/2210001/", "progressUnit": "episodes",
                  "progressCurrent": 7, "progressTotal": 46 },
                { "id": "F621E1F8-C36C-495A-93FC-0C247A3E6E60", "title": "旧条目", "type": "影视",
                  "progressUnit": "季" }
              ]
            }
            """, in: dir)
            guard case .loaded(let items) = LibraryMigration.load(from: dir) else {
                return check(false, "含新字段的 v3 文档应可加载")
            }
            checkEqual(items[0].referenceURL, "https://movie.douban.com/subject/2210001/", "referenceURL 解析")
            checkEqual(items[0].progressUnit, .episodes, "progressUnit 解析")
            checkEqual(items[0].progressText, "第 7 / 46 集", "按集进度文案")
            checkNil(items[1].referenceURL, "缺 referenceURL 字段容错为 nil")
            checkNil(items[1].progressUnit, "未知 progressUnit 值容错为 nil")
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

        // 进度单位（仅影视可选分钟 / 集 / 期；其余类型按类型默认）
        do {
            var item = MediaItem(title: "剧集", type: .movie)
            item.progressCurrent = 7
            item.progressTotal = 46
            checkEqual(item.progressText, "7 分钟 / 46 分钟", "默认分钟进度文案")
            checkEqual(item.progressStep, 10, "分钟步进 ±10")
            item.progressUnit = .episodes
            checkEqual(item.progressText, "第 7 / 46 集", "按集进度文案")
            checkEqual(item.progressUnitLabel, "集", "按集单位文案")
            checkEqual(item.progressStep, 1, "按集步进 ±1")
            item.progressUnit = .issues
            checkEqual(item.progressText, "第 7 / 46 期", "按期进度文案")
            item.progressUnit = .episodes
            item.progressCurrent = 50   // 超出总量时文案钳制
            checkEqual(item.progressText, "第 46 / 46 集", "按集进度超出总量钳制展示")
        }

        // finish 无条件补满：无总量时清零旧进度残留
        withTempDir { dir in
            let store = LibraryStore(directory: dir)
            var item = MediaItem(title: "测试", type: .movie)
            item.status = .inProgress
            item.progressCurrent = 30   // 旧数据残留（无总量）
            store.add(item)
            store.finish(item)
            let updated = store.item(for: item.id)
            checkEqual(updated?.status, .completed, "无总量品完后状态")
            checkEqual(updated?.progressCurrent, 0, "无总量品完清空进度残留")
        }

        // updateProgress：无总量时忽略 current 写入
        withTempDir { dir in
            let store = LibraryStore(directory: dir)
            let item = MediaItem(title: "测试", type: .movie)
            store.add(item)
            store.updateProgress(item, current: 50)
            let updated = store.item(for: item.id)
            checkEqual(updated?.progressCurrent, 0, "无总量不写入当前进度")
            checkEqual(updated?.status, .planned, "无总量不触发流转")
            checkNil(updated?.lastTastedAt, "无总量无变化不刷新最近品味时间")
        }

        // setTotal：仅写总量，不截断、不流转、不动最近品味时间
        withTempDir { dir in
            let store = LibraryStore(directory: dir)
            var item = MediaItem(title: "测试", type: .movie)
            item.status = .inProgress
            item.progressCurrent = 80
            item.progressTotal = 100
            item.lastTastedAt = Date(timeIntervalSinceReferenceDate: 700000000)
            store.add(item)
            store.setTotal(item, total: 60)
            let updated = store.item(for: item.id)
            checkEqual(updated?.progressTotal, 60, "setTotal 写入总量")
            checkEqual(updated?.progressCurrent, 80, "setTotal 不截断当前进度")
            checkEqual(updated?.status, .inProgress, "setTotal 不触发流转")
            checkEqual(updated?.lastTastedAt, Date(timeIntervalSinceReferenceDate: 700000000),
                       "setTotal 不动最近品味时间")
            store.setTotal(item, total: -5)
            checkEqual(store.item(for: item.id)?.progressTotal, 0, "setTotal 负值钳到 0")
            // 展示层：current 超出 total 时文案钳制，存储不动
            checkEqual(MediaType.movie.progressText(current: 80, total: 60), "60 分钟 / 60 分钟",
                       "进度文案超出总量时钳制展示")
        }

        // switchProgressUnit：单位切换属元数据修改——清零重计量，不流转、不动最近品味时间
        withTempDir { dir in
            let store = LibraryStore(directory: dir)
            var item = MediaItem(title: "测试", type: .movie)
            item.status = .inProgress
            item.progressUnit = .episodes
            item.progressCurrent = 7
            item.progressTotal = 46
            item.lastTastedAt = Date(timeIntervalSinceReferenceDate: 700000000)
            store.add(item)
            store.switchProgressUnit(item, to: nil)
            let updated = store.item(for: item.id)
            checkNil(updated?.progressUnit, "切回分钟后单位清空")
            checkEqual(updated?.progressCurrent, 0, "切单位后当前进度清零")
            checkEqual(updated?.progressTotal, 0, "切单位后总量清零")
            checkEqual(updated?.status, .inProgress, "切单位不触发状态流转")
            checkEqual(updated?.lastTastedAt, Date(timeIntervalSinceReferenceDate: 700000000),
                       "切单位不动最近品味时间")
        }

        // 已完成条目进度拉低到总量以下：回落进行中
        withTempDir { dir in
            let store = LibraryStore(directory: dir)
            var item = MediaItem(title: "测试", type: .movie)
            item.status = .completed
            item.progressCurrent = 100
            item.progressTotal = 100
            store.add(item)
            store.updateProgress(item, current: 50)
            let updated = store.item(for: item.id)
            checkEqual(updated?.progressCurrent, 50, "已完成条目进度可拉低")
            checkEqual(updated?.status, .inProgress, "进度低于总量回落进行中")
        }

        // lastTastedAt 仅在正增量 / 流转时刷新
        withTempDir { dir in
            let store = LibraryStore(directory: dir)
            var item = MediaItem(title: "测试", type: .movie)
            item.status = .inProgress
            store.add(item)
            store.updateProgress(item, current: 40, total: 100)
            let t1 = store.item(for: item.id)?.lastTastedAt
            checkNotNil(t1, "正增量刷新最近品味时间")

            store.updateProgress(item, current: 40)     // 无变化
            checkEqual(store.item(for: item.id)?.lastTastedAt, t1, "无变化不刷新")

            store.updateProgress(item, current: 20)     // 进度减小
            checkEqual(store.item(for: item.id)?.progressCurrent, 20, "进度可下调")
            checkEqual(store.item(for: item.id)?.lastTastedAt, t1, "进度减小不刷新")

            store.updateProgress(item, current: 20, total: 120) // 仅设总量
            checkEqual(store.item(for: item.id)?.lastTastedAt, t1, "仅设总量不刷新")

            store.updateProgress(item, current: 30)     // 再次正增量
            check(store.item(for: item.id)?.lastTastedAt != t1, "再次正增量刷新")
        }

        // markTasted：仅记录最近品味时间
        withTempDir { dir in
            let store = LibraryStore(directory: dir)
            let item = MediaItem(title: "测试", type: .movie)
            store.add(item)
            store.markTasted(item)
            let updated = store.item(for: item.id)
            checkNotNil(updated?.lastTastedAt, "markTasted 记录最近品味时间")
            checkEqual(updated?.status, .planned, "markTasted 不改状态")
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

        // 封面回填：指向真实文件的路径不覆盖；本地文件被删后允许重新回填
        withTempDir { dir in
            let store = LibraryStore(directory: dir)
            let realCover = dir.appendingPathComponent("cover-a.jpg")
            try! Data([0xFF, 0xD8, 0xFF]).write(to: realCover)   // 真实存在的文件
            let item = MediaItem(title: "测试", type: .movie)
            store.add(item)
            store.backfillCover(id: item.id, path: realCover.path)
            checkEqual(store.item(for: item.id)?.localCoverPath, realCover.path, "封面回填")

            // 原路径指向真实存在的文件：保持「只回填一次」
            store.backfillCover(id: item.id, path: dir.appendingPathComponent("cover-b.jpg").path)
            checkEqual(store.item(for: item.id)?.localCoverPath, realCover.path, "真实文件不回填覆盖")

            // 本地封面文件被删除：回填允许替换为新路径（删除后重下载恢复）
            try? FileManager.default.removeItem(at: realCover)
            store.backfillCover(id: item.id, path: "/tmp/cover-c.jpg")
            checkEqual(store.item(for: item.id)?.localCoverPath, "/tmp/cover-c.jpg", "缺失文件允许重新回填")
        }

        // 资料链接归位：旧版误填进 webURL 的资料站链接搬回 referenceURL，观看链接不动
        withTempDir { dir in
            write("""
            {
              "schemaVersion": 3,
              "exportedAt": 700000000,
              "items": [
                { "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F", "title": "旧影视", "type": "影视",
                  "webURL": "https://movie.douban.com/subject/2210001/" },
                { "id": "F621E1F8-C36C-495A-93FC-0C247A3E6E60", "title": "手动补的观看链接", "type": "影视",
                  "webURL": "https://www.youtube.com/watch?v=abc" },
                { "id": "A621E1F8-C36C-495A-93FC-0C247A3E6E5F", "title": "伪装域名不动", "type": "影视",
                  "webURL": "https://notdouban.com/x" }
              ]
            }
            """, in: dir)
            let store = LibraryStore(directory: dir)
            let douban = store.items.first { $0.title == "旧影视" }
            checkNil(douban?.webURL, "豆瓣链接搬出观看链接")
            checkEqual(douban?.referenceURL, "https://movie.douban.com/subject/2210001/", "豆瓣链接归入资料链接")
            let youtube = store.items.first { $0.title == "手动补的观看链接" }
            checkEqual(youtube?.webURL, "https://www.youtube.com/watch?v=abc", "YouTube 观看链接不动")
            checkNil(youtube?.referenceURL, "YouTube 条目无资料链接")
            let fake = store.items.first { $0.title == "伪装域名不动" }
            checkEqual(fake?.webURL, "https://notdouban.com/x", "伪装域名不误搬")
        }
    }

    // MARK: - 导入解析（版本校验 / 去重 / 回填）

    @MainActor
    private static func ioSuite() {
        print("[导入]")

        let existingID = UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!
        let json = """
        {
          "schemaVersion": 3,
          "exportedAt": 700000000,
          "items": [
            { "id": "\(existingID.uuidString)", "title": "库内已存在", "type": "影视" },
            { "id": "A621E1F8-C36C-495A-93FC-0C247A3E6E5F", "title": "新条目", "type": "书籍",
              "status": "inProgress", "dateAdded": 700000000, "lastViewedDate": 700010000 },
            { "id": "A621E1F8-C36C-495A-93FC-0C247A3E6E5F", "title": "文件内重复", "type": "书籍" },
            { "id": "B621E1F8-C36C-495A-93FC-0C247A3E6E60", "title": "另一条", "type": "音乐" }
          ]
        }
        """
        do {
            let items = try LibraryIO.parseImport(json.data(using: .utf8)!, existingIDs: [existingID])
            checkEqual(items.count, 2, "导入跳过库内已有与文件内重复 id")
            checkEqual(items[0].title, "新条目", "导入保留顺序")
            checkEqual(items[0].lastTastedAt, Date(timeIntervalSinceReferenceDate: 700010000),
                       "导入回填进行中条目的最近品味时间")
        } catch {
            check(false, "合法导入应成功", "\(error)")
        }

        let wrongVersion = #"{ "schemaVersion": 2, "items": [] }"#.data(using: .utf8)!
        check((try? LibraryIO.parseImport(wrongVersion, existingIDs: [])) == nil, "版本不符拒绝导入")

        let garbage = "not json".data(using: .utf8)!
        check((try? LibraryIO.parseImport(garbage, existingIDs: [])) == nil, "非 JSON 拒绝导入")
    }
}
#endif
