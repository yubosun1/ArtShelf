// PreviewRenderer.swift —— 离屏渲染预览（仅 Debug）
// 用法：swift run ArtShelf --render-preview <输出目录>
// 用演示数据把真实视图渲染成 PNG，供无 Xcode / 无截屏权限环境下做视觉对照。
#if DEBUG
import SwiftUI
import AppKit

@MainActor
enum PreviewRenderer {

    static func run(outputDir: String) -> Int32 {
        let out = URL(fileURLWithPath: outputDir, isDirectory: true)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        // 演示库：临时目录，不触碰真实数据
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArtShelfPreview-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = LibraryStore(directory: tempDir)
        seed(store)

        let appState = AppState()
        let dark = NSAppearance(named: .darkAqua)!
        let light = NSAppearance(named: .aqua)!

        // 此刻：深浅双渲染（加高窗口，检验整页氛围场在全窗高的连续覆盖）
        render(ContentView(), store: store, appState: appState, appearance: dark, to: out, name: "1-now-dark", height: 1300)
        render(ContentView(), store: store, appState: appState, appearance: light, to: out, name: "2-now-light", height: 1300)
        // 三个库页 + 统计（深色；库页加高同理——内容不足一屏正是氛围场覆盖的边界情形）
        for (tab, name) in [(AppTab.movies, "3-movies-dark"), (.music, "4-music-dark"), (.books, "5-books-dark"), (.stats, "6-stats-dark")] {
            appState.tab = tab
            render(ContentView(), store: store, appState: appState, appearance: dark, to: out, name: name,
                   height: tab == .stats ? 1240 : 1300)
        }
        // 详情整版（深色）：用按集进度的剧集，高度加大以覆盖完整右栏
        appState.tab = .now
        if let hero = store.items.first(where: { $0.title == "大明王朝1566" }) {
            appState.openDetail(hero)
            render(ContentView(), store: store, appState: appState, appearance: dark, to: out, name: "7-detail-dark", height: 1300)
        }
        appState.closeDetail()

        // 设置页（深色）：外观主题色样 / 应用图标切换
        render(SettingsView(), store: store, appState: appState, appearance: dark, to: out, name: "8-settings-dark",
               width: 500, height: 640)

        print("预览已渲染到 \(out.path)")
        return 0
    }

    // MARK: - 离屏渲染

    /// theme 非 nil 时先切换全局主题再渲染（渲染完恢复原主题，净 UserDefaults 副作用为零）
    private static func render<V: View>(
        _ view: V,
        store: LibraryStore,
        appState: AppState,
        appearance: NSAppearance,
        theme: AppTheme? = nil,
        to dir: URL,
        name: String,
        width: CGFloat = 1240,
        height: CGFloat = 820
    ) {
        let originalTheme = ThemeSettings.shared.theme
        if let theme { ThemeSettings.shared.theme = theme }
        defer {
            if theme != nil { ThemeSettings.shared.theme = originalTheme }
        }

        let root = view
            .environment(appState)
            .environment(store)
            .frame(width: width, height: height)
            .background(Theme.bg)   // 与 ArtShelfApp 一致的画布底色
        let hosting = NSHostingView(rootView: root)

        // 窗口移到屏幕外再 order in——对用户不可见，但视图树获得完整 backing 可渲染
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.appearance = theme?.nsAppearance ?? appearance
        window.contentView = hosting
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        window.orderBack(nil)

        // 跑若干 runloop 周期，让布局、.task 本地状态同步与异步渲染完成
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(1.0))
        hosting.layoutSubtreeIfNeeded()

        if let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) {
            hosting.cacheDisplay(in: hosting.bounds, to: rep)
            if let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: dir.appendingPathComponent("\(name).png"))
            }
        }
        window.close()
    }

    // MARK: - 演示数据（对齐概念稿）

    private static func seed(_ store: LibraryStore) {
        let now = Date()

        func make(
            _ title: String, _ type: MediaType, status: MediaStatus,
            creator: String? = nil, year: Int? = nil, rating: Int = 0,
            current: Int = 0, total: Int = 0, tags: [String] = [],
            genre: String? = nil, note: String? = nil, replay: Int = 0,
            tastedOffset: TimeInterval? = nil, unit: ProgressUnit? = nil,
            addedOffset: TimeInterval? = nil,
            watch: String? = nil, reference: String? = nil
        ) -> MediaItem {
            var item = MediaItem(title: title, type: type)
            item.creator = creator
            item.year = year
            item.rating = rating
            item.status = status
            item.progressCurrent = current
            item.progressTotal = total
            item.progressUnit = unit
            item.webURL = watch
            item.referenceURL = reference
            item.tags = tags
            item.genre = genre
            item.replayCount = replay
            if let tastedOffset {
                item.lastTastedAt = now.addingTimeInterval(tastedOffset)
            }
            if let addedOffset {
                item.dateAdded = now.addingTimeInterval(addedOffset)
            }
            if let note {
                item.notes = [NoteEntry(text: note, createdAt: now.addingTimeInterval(-3600))]
            }
            store.add(item)
            return item
        }

        // 收录日期（addedOffset，单位天）摊开在近 5 个月，供统计页热力图 / 月度趋势预览

        // 影视
        make("花样年华", .movie, status: .inProgress, creator: "王家卫", year: 2000, rating: 5,
             current: 61, total: 98, tags: ["港片", "王家卫", "二刷清单"], genre: "剧情 / 爱情",
             note: "走廊里那盏灯、云吞面蒸起的热气，和所有没说出口的话。梅林茂的弦乐一起，时间就退回了那个年代。",
             replay: 2, tastedOffset: 0, addedOffset: -2 * 86400)
        // 剧集：按集计进度（预览详情页单位切换与「第 X / Y 集」文案）
        make("大明王朝1566", .movie, status: .inProgress, creator: "张黎", year: 2007, rating: 5,
             current: 22, total: 46, tags: ["历史"], genre: "古装剧 · 历史片",
             note: "改稻为桑，一盘棋下出了整个王朝的困局。",
             tastedOffset: -60, unit: .episodes, addedOffset: -6 * 86400,
             watch: "https://www.bilibili.com/bangumi/play/example",
             reference: "https://movie.douban.com/subject/2210001/")
        make("星际穿越", .movie, status: .inProgress, creator: "诺兰", year: 2014,
             current: 105, total: 169, tastedOffset: -7200, addedOffset: -10 * 86400)
        make("布达佩斯大饭店", .movie, status: .completed, creator: "韦斯·安德森", year: 2014, rating: 4,
             addedOffset: -16 * 86400)
        make("千与千寻", .movie, status: .completed, creator: "宫崎骏", year: 2001, rating: 5,
             addedOffset: -42 * 86400)
        make("教父", .movie, status: .planned, creator: "科波拉", year: 1972,
             addedOffset: -78 * 86400)
        make("低俗小说", .movie, status: .planned, creator: "昆汀", year: 1994,
             addedOffset: -85 * 86400)

        // 音乐
        make("async", .music, status: .inProgress, creator: "坂本龙一", year: 2017,
             current: 3, total: 12, tastedOffset: -3600, addedOffset: -3 * 86400)
        make("冀西南林路行", .music, status: .inProgress, creator: "万能青年旅店", year: 2020,
             current: 6, total: 11, tastedOffset: -5400, addedOffset: -13 * 86400)
        make("OK Computer", .music, status: .completed, creator: "Radiohead", year: 1997, rating: 5,
             addedOffset: -52 * 86400)
        make("月之暗面", .music, status: .completed, creator: "Pink Floyd", year: 1973, rating: 5,
             addedOffset: -98 * 86400)
        make("Waltz for Debby", .music, status: .completed, creator: "Bill Evans", year: 1961,
             addedOffset: -125 * 86400)
        make("folklore", .music, status: .completed, creator: "Taylor Swift", year: 2020, rating: 4,
             addedOffset: -105 * 86400)
        make("Abbey Road", .music, status: .completed, creator: "The Beatles", year: 1969, rating: 5,
             addedOffset: -145 * 86400)
        make("Modal Soul", .music, status: .planned, creator: "Nujabes", year: 2005,
             addedOffset: -31 * 86400)

        // 书籍
        make("百年孤独", .book, status: .inProgress, creator: "马尔克斯",
             current: 128, total: 256, tastedOffset: -1800, addedOffset: -1 * 86400)
        make("活着", .book, status: .completed, creator: "余华", rating: 5,
             current: 191, total: 191, note: "读完沉默良久。", addedOffset: -62 * 86400)
        make("人类简史", .book, status: .completed, creator: "赫拉利", rating: 4,
             addedOffset: -90 * 86400)
        make("看不见的城市", .book, status: .planned, creator: "卡尔维诺",
             addedOffset: -21 * 86400)
        make("小径分岔的花园", .book, status: .planned, creator: "博尔赫斯",
             addedOffset: -48 * 86400)
    }
}
#endif
