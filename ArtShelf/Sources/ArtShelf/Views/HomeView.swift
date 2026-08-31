import SwiftUI

/// 艺术画廊主页 (Artisan Atelier Home)
///
/// 彻底解决不同媒体封面长宽比冲突的问题：
/// - 顶部：艺术策展数据矩阵，直观展示影视、音乐、书籍的收录量与在看/已看进度；
/// - 中部：正在品味（In Progress）焦点条；
/// - 下部：三大媒体专属展示架（2:3 胶片海报、1:1 方形黑胶、2:3 典雅书衣），各自等比水平陈列，配有“查看全部 ›”一键直达。
struct HomeView: View {

    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState

    /// 主页馆藏分桶结果：单次遍历按媒体类型与“进行中”状态分组，避免多处独立 filter 重复扫描全量数据
    private struct HomeBuckets {
        var movies: [MediaItem] = []
        var music: [MediaItem] = []
        var books: [MediaItem] = []
        var inProgress: [MediaItem] = []

        var totalCount: Int { movies.count + music.count + books.count }
    }

    /// 一次遍历完成分桶（保留 store.items 原有相对顺序，行为与旧的四处 filter 一致）
    private func makeBuckets() -> HomeBuckets {
        var buckets = HomeBuckets()
        for item in store.items {
            switch item.type {
            case .movie: buckets.movies.append(item)
            case .music: buckets.music.append(item)
            case .book: buckets.books.append(item)
            }
            if item.status == .inProgress {
                buckets.inProgress.append(item)
            }
        }
        return buckets
    }

    var body: some View {
        // 单次遍历分桶，供所有分栏共用，避免重复扫描全量数据
        let buckets = makeBuckets()

        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 32) {
                welcomeHeader(buckets: buckets)
                statsMatrix(buckets: buckets)

                if !buckets.inProgress.isEmpty {
                    inProgressSection(items: buckets.inProgress)
                }

                if !buckets.movies.isEmpty {
                    mediaShelfSection(
                        title: "影视精选",
                        subtitle: "光影回响与电影胶片",
                        icon: "film.stack.fill",
                        type: .movie,
                        items: buckets.movies,
                        cardWidth: 142,
                        aspectRatio: 2.0 / 3.0
                    )
                }

                if !buckets.music.isEmpty {
                    mediaShelfSection(
                        title: "黑胶唱片",
                        subtitle: "回转唱针与专辑艺术",
                        icon: "opticaldisc.fill",
                        type: .music,
                        items: buckets.music,
                        cardWidth: 146,
                        aspectRatio: 1.0
                    )
                }

                if !buckets.books.isEmpty {
                    mediaShelfSection(
                        title: "案头藏书",
                        subtitle: "书卷装帧与慢读岁月",
                        icon: "books.vertical.fill",
                        type: .book,
                        items: buckets.books,
                        cardWidth: 142,
                        aspectRatio: 2.0 / 3.0
                    )
                }

                if store.items.isEmpty {
                    emptyHomePrompt
                }
            }
            .padding(.horizontal, ArtShelfStyle.contentPadding)
            .padding(.top, 40)
            .padding(.bottom, 48)
        }
        .background(ArtShelfStyle.paper)
        .sheet(item: $appState.detailItem) { item in
            DetailView(item: item)
                .environmentObject(store)
                .environmentObject(appState)
        }
    }

    // MARK: - 欢迎页眉

    private func welcomeHeader(buckets: HomeBuckets) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16))
                        .foregroundStyle(ArtShelfStyle.accent)

                    Text("我的艺术藏室")
                        .font(ArtShelfStyle.pageTitle)
                        .foregroundStyle(ArtShelfStyle.ink)
                }

                Text(curationSummaryText(buckets: buckets))
                    .font(.system(size: 13))
                    .foregroundStyle(ArtShelfStyle.inkSecondary)
            }

            Spacer()

            Button {
                appState.showingAddSheet = true
            } label: {
                Label("添加新藏品", systemImage: "plus")
                    .font(.system(size: 12.5, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
            }
            .buttonStyle(.borderedProminent)
            .tint(ArtShelfStyle.accent)
        }
    }

    private func curationSummaryText(buckets: HomeBuckets) -> String {
        if buckets.totalCount == 0 {
            return "开始搭建您的个人多媒体典藏空间"
        }
        var parts: [String] = []
        if !buckets.movies.isEmpty { parts.append("\(buckets.movies.count) 部影视") }
        if !buckets.music.isEmpty { parts.append("\(buckets.music.count) 张唱片") }
        if !buckets.books.isEmpty { parts.append("\(buckets.books.count) 本书籍") }
        return "珍藏了 " + parts.joined(separator: " · ") + " · 共 \(buckets.totalCount) 件作品"
    }

    // MARK: - 策展数据矩阵卡片 (Stats Matrix)

    private func statsMatrix(buckets: HomeBuckets) -> some View {
        HStack(spacing: 16) {
            statCard(
                title: "光影展厅",
                type: .movie,
                icon: "film.stack.fill",
                accentColor: Color(red: 0.88, green: 0.32, blue: 0.22),
                items: buckets.movies
            )

            statCard(
                title: "黑胶唱片室",
                type: .music,
                icon: "opticaldisc.fill",
                accentColor: Color(red: 0.90, green: 0.58, blue: 0.16),
                items: buckets.music
            )

            statCard(
                title: "书斋阅览",
                type: .book,
                icon: "books.vertical.fill",
                accentColor: Color(red: 0.24, green: 0.65, blue: 0.44),
                items: buckets.books
            )
        }
    }

    private func statCard(
        title: String,
        type: MediaType,
        icon: String,
        accentColor: Color,
        items: [MediaItem]
    ) -> some View {
        StatCardView(
            title: title,
            type: type,
            icon: icon,
            accentColor: accentColor,
            items: items
        ) {
            appState.navigateToCategory(type)
        }
    }

    // MARK: - 正在品味焦点区 (In Progress)

    private func inProgressSection(items: [MediaItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(red: 0.92, green: 0.58, blue: 0.16))
                    .frame(width: 7, height: 7)

                Text("正在品味")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ArtShelfStyle.ink)

                Text("· 正在进行中的藏品")
                    .font(.system(size: 12))
                    .foregroundStyle(ArtShelfStyle.inkTertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(items) { item in
                        InProgressCard(item: item) {
                            appState.detailItem = item
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - 专属陈列展台 (Media Shelf Section)

    private func mediaShelfSection(
        title: String,
        subtitle: String,
        icon: String,
        type: MediaType,
        items: [MediaItem],
        cardWidth: CGFloat,
        aspectRatio: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 7) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ArtShelfStyle.accent)

                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(ArtShelfStyle.ink)

                    Text("· \(subtitle)")
                        .font(.system(size: 12))
                        .foregroundStyle(ArtShelfStyle.inkTertiary)
                }

                Spacer()

                Button {
                    appState.navigateToCategory(type)
                } label: {
                    HStack(spacing: 4) {
                        let unit: String = type == .movie ? "部影视" : (type == .music ? "张唱片" : "本书籍")
                        Text("查看全部 \(items.count) \(unit)")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(ArtShelfStyle.accent)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 18) {
                    ForEach(items.prefix(12)) { item in
                        HomeShelfCard(
                            item: item,
                            width: cardWidth,
                            aspectRatio: aspectRatio
                        ) {
                            appState.detailItem = item
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - 空主页引导

    private var emptyHomePrompt: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 38))
                .foregroundStyle(ArtShelfStyle.accent.opacity(0.8))

            Text("您的个人媒体画廊尚无藏品")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ArtShelfStyle.ink)

            Text("点击下方按钮添加你看过的电影、在听的唱片，或想读的书籍。")
                .font(.system(size: 12.5))
                .foregroundStyle(ArtShelfStyle.inkSecondary)

            Button {
                appState.showingAddSheet = true
            } label: {
                Label("添加第一份收藏", systemImage: "plus")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(ArtShelfStyle.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .panelBackground(radius: 12)
    }
}

// MARK: - 策展统计卡片组件

private struct StatCardView: View {
    let title: String
    let type: MediaType
    let icon: String
    let accentColor: Color
    let items: [MediaItem]
    let action: () -> Void

    @State private var isHovered = false

    private var completedCount: Int {
        items.filter { $0.status == .completed }.count
    }

    private var inProgressCount: Int {
        items.filter { $0.status == .inProgress }.count
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .frame(width: 26, height: 26)
                        .background(accentColor.opacity(0.12), in: Circle())

                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ArtShelfStyle.ink)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(ArtShelfStyle.inkTertiary)
                        .opacity(isHovered ? 1 : 0.4)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(items.count)")
                        .font(.system(size: 26, weight: .bold).monospacedDigit())
                        .foregroundStyle(ArtShelfStyle.ink)

                    Text(type == .movie ? "部" : (type == .music ? "张" : "本"))
                        .font(.system(size: 11))
                        .foregroundStyle(ArtShelfStyle.inkTertiary)
                }

                HStack(spacing: 8) {
                    Text("\(completedCount) \(type.completedLabel)")
                        .font(.system(size: 11))
                        .foregroundStyle(ArtShelfStyle.inkSecondary)

                    if inProgressCount > 0 {
                        Text("·")
                            .foregroundStyle(ArtShelfStyle.inkTertiary)
                        Text("\(inProgressCount) \(type.inProgressLabel)")
                            .font(.system(size: 11))
                            .foregroundStyle(accentColor)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .panelBackground(radius: 10)
            .offset(y: isHovered ? -2 : 0)
            .shadow(
                color: isHovered ? Color.black.opacity(0.10) : Color.black.opacity(0.04),
                radius: isHovered ? 10 : 4,
                x: 0,
                y: isHovered ? 4 : 2
            )
            .animation(.easeOut(duration: 0.16), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - 正在品味焦点卡片

private struct InProgressCard: View {
    let item: MediaItem
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if item.type == .music {
                    MusicCoverView(
                        localPath: item.localCoverPath,
                        remoteURL: item.coverURL,
                        size: 48,
                        cornerRadius: 5,
                        isHovered: isHovered
                    )
                } else if item.type == .movie {
                    MovieCoverView(
                        localPath: item.localCoverPath,
                        remoteURL: item.coverURL,
                        size: 48,
                        cornerRadius: 5,
                        isHovered: isHovered
                    )
                } else {
                    // 迷你 48pt 封面不启用翻页细节（小尺寸下糊成一团），仅保留卡片整体轻浮起
                    BookCoverView(
                        localPath: item.localCoverPath,
                        remoteURL: item.coverURL,
                        size: 48,
                        cornerRadius: 5
                    )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(ArtShelfStyle.ink)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        StatusBadge(status: item.status, type: item.type)

                        if let creator = item.creator, !creator.isEmpty {
                            Text(creator)
                                .font(.system(size: 11))
                                .foregroundStyle(ArtShelfStyle.inkTertiary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(ArtShelfStyle.accent)
                    .opacity(isHovered ? 1 : 0.6)
            }
            .padding(10)
            .frame(width: 250)
            .panelBackground(radius: 8)
            .offset(y: isHovered ? -2 : 0)
            .shadow(color: isHovered ? Color.black.opacity(0.08) : Color.clear, radius: 8, y: 3)
            .animation(.easeOut(duration: 0.14), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - 主页专属陈列卡片 (HomeShelfCard)

private struct HomeShelfCard: View {
    let item: MediaItem
    let width: CGFloat
    let aspectRatio: CGFloat
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    if item.type == .music {
                        MusicCoverView(
                            localPath: item.localCoverPath,
                            remoteURL: item.coverURL,
                            size: width,
                            cornerRadius: ArtShelfStyle.cardRadius,
                            isHovered: isHovered
                        )
                        .cardHoverEffect(isHovered: isHovered)
                    } else if item.type == .movie {
                        MovieCoverView(
                            localPath: item.localCoverPath,
                            remoteURL: item.coverURL,
                            size: width,
                            cornerRadius: ArtShelfStyle.cardRadius,
                            isHovered: isHovered
                        )
                        .cardHoverEffect(isHovered: isHovered)
                    } else {
                        BookCoverView(
                            localPath: item.localCoverPath,
                            remoteURL: item.coverURL,
                            size: width,
                            cornerRadius: ArtShelfStyle.cardRadius,
                            isHovered: isHovered
                        )
                        .cardHoverEffect(isHovered: isHovered)
                    }

                    if isHovered {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(ArtShelfStyle.ink)
                            .frame(width: 24, height: 24)
                            .background(.ultraThinMaterial, in: Circle())
                            .padding(6)
                            .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(ArtShelfStyle.ink)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(item.status.label(for: item.type))
                            .font(.system(size: 10.5))
                            .foregroundStyle(item.status.color)

                        if let creator = item.creator, !creator.isEmpty {
                            Text("·")
                                .foregroundStyle(ArtShelfStyle.inkTertiary)
                            Text(creator)
                                .font(.system(size: 10.5))
                                .foregroundStyle(ArtShelfStyle.inkSecondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 2)

                        if let year = item.year {
                            Text(String(year))
                                .font(.system(size: 10.5).monospacedDigit())
                                .foregroundStyle(ArtShelfStyle.inkTertiary)
                        }
                    }
                }
                .frame(width: width, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) { isHovered = hovering }
        }
    }
}
