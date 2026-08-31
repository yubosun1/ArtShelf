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

        // 此刻：深浅双渲染
        render(ContentView(), store: store, appState: appState, appearance: dark, to: out, name: "1-now-dark")
        render(ContentView(), store: store, appState: appState, appearance: light, to: out, name: "2-now-light")
        // 三个库页 + 统计（深色）
        for (tab, name) in [(AppTab.movies, "3-movies-dark"), (.music, "4-music-dark"), (.books, "5-books-dark"), (.stats, "6-stats-dark")] {
            appState.tab = tab
            render(ContentView(), store: store, appState: appState, appearance: dark, to: out, name: name)
        }
        // 详情整版（深色）
        appState.tab = .now
        if let hero = store.items.first(where: { $0.title == "花样年华" }) {
            appState.openDetail(hero)
            render(ContentView(), store: store, appState: appState, appearance: dark, to: out, name: "7-detail-dark")
        }

        print("预览已渲染到 \(out.path)")
        return 0
    }

    // MARK: - 离屏渲染

    private static func render<V: View>(
        _ view: V,
        store: LibraryStore,
        appState: AppState,
        appearance: NSAppearance,
        to dir: URL,
        name: String
    ) {
        let root = view
            .environment(appState)
            .environment(store)
            .frame(width: 1240, height: 820)
            .background(Theme.bg)   // 与 ArtShelfApp 一致的画布底色
        let hosting = NSHostingView(rootView: root)

        // 窗口移到屏幕外再 order in——对用户不可见，但视图树获得完整 backing 可渲染
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1240, height: 820),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.appearance = appearance
        window.contentView = hosting
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        window.orderBack(nil)

        // 跑两个 runloop 周期，让布局与异步渲染完成
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.35))
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
            tastedOffset: TimeInterval? = nil
        ) -> MediaItem {
            var item = MediaItem(title: title, type: type)
            item.creator = creator
            item.year = year
            item.rating = rating
            item.status = status
            item.progressCurrent = current
            item.progressTotal = total
            item.tags = tags
            item.genre = genre
            item.replayCount = replay
            if let tastedOffset {
                item.lastTastedAt = now.addingTimeInterval(tastedOffset)
            }
            if let note {
                item.notes = [NoteEntry(text: note, createdAt: now.addingTimeInterval(-3600))]
            }
            store.add(item)
            return item
        }

        // 影视
        make("花样年华", .movie, status: .inProgress, creator: "王家卫", year: 2000, rating: 5,
             current: 61, total: 98, tags: ["港片", "王家卫", "二刷清单"], genre: "剧情 / 爱情",
             note: "走廊里那盏灯、云吞面蒸起的热气，和所有没说出口的话。梅林茂的弦乐一起，时间就退回了那个年代。",
             replay: 2, tastedOffset: 0)
        make("星际穿越", .movie, status: .inProgress, creator: "诺兰", year: 2014,
             current: 105, total: 169, tastedOffset: -7200)
        make("布达佩斯大饭店", .movie, status: .completed, creator: "韦斯·安德森", year: 2014, rating: 4)
        make("千与千寻", .movie, status: .completed, creator: "宫崎骏", year: 2001, rating: 5)
        make("教父", .movie, status: .planned, creator: "科波拉", year: 1972)
        make("低俗小说", .movie, status: .planned, creator: "昆汀", year: 1994)

        // 音乐
        make("async", .music, status: .inProgress, creator: "坂本龙一", year: 2017,
             current: 3, total: 12, tastedOffset: -3600)
        make("冀西南林路行", .music, status: .inProgress, creator: "万能青年旅店", year: 2020,
             current: 6, total: 11, tastedOffset: -5400)
        make("OK Computer", .music, status: .completed, creator: "Radiohead", year: 1997, rating: 5)
        make("月之暗面", .music, status: .completed, creator: "Pink Floyd", year: 1973, rating: 5)
        make("Waltz for Debby", .music, status: .completed, creator: "Bill Evans", year: 1961)
        make("folklore", .music, status: .completed, creator: "Taylor Swift", year: 2020, rating: 4)
        make("Abbey Road", .music, status: .completed, creator: "The Beatles", year: 1969, rating: 5)
        make("Modal Soul", .music, status: .planned, creator: "Nujabes", year: 2005)

        // 书籍
        make("百年孤独", .book, status: .inProgress, creator: "马尔克斯",
             current: 128, total: 256, tastedOffset: -1800)
        make("活着", .book, status: .completed, creator: "余华", rating: 5,
             current: 191, total: 191, note: "读完沉默良久。")
        make("人类简史", .book, status: .completed, creator: "赫拉利", rating: 4)
        make("看不见的城市", .book, status: .planned, creator: "卡尔维诺")
        make("小径分岔的花园", .book, status: .planned, creator: "博尔赫斯")
    }
}
#endif
