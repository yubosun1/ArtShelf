import SwiftUI

/// 库页：片库 / 唱片 / 书架三 Tab 共用的瀑布网格
///
/// 顶部为库名 + 藏品计数，工具行依次为本页搜索框、状态筛选胶囊、排序菜单；
/// 主体是自适应列宽的封面网格（最小列宽 158）。搜索 / 筛选 / 排序均为内存过滤
/// （`typeRaw` 私有，不写 #Predicate）。空库时引导收录，筛选无结果时提示清除条件。
struct LibraryView: View {

    let type: MediaType

    @Environment(AppState.self) private var appState
    @Environment(LibraryStore.self) private var store

    @State private var query = ""
    @State private var statusFilter: StatusFilter = .all
    @State private var sortMode: SortMode = .smart

    /// 库名：影视→片库 / 音乐→唱片 / 书籍→书架
    private var libraryTitle: String {
        switch type {
        case .movie: return "片库"
        case .music: return "唱片"
        case .book:  return "书架"
        }
    }

    /// 当前类型的全部藏品（未排序）
    private var typed: [MediaItem] { store.items.filter { $0.type == type } }

    /// 搜索 + 状态筛选 + 排序后的展示结果
    private var results: [MediaItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        // 搜索字段口径复用全局检索逻辑，仅把范围收窄到当前类型
        var xs = q.isEmpty ? typed : GlobalSearchView.filter(typed, query: q)
        xs = xs.filter { statusFilter.matches($0.status) }
        return sorted(xs)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, Theme.sectionSpacing)
                    .padding(.bottom, 20)
                toolRow
                    .padding(.bottom, 28)
                content
            }
            .padding(.horizontal, Theme.contentPadding)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - 顶部标题区

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(libraryTitle)
                .font(Theme.sectionTitle)
                .foregroundStyle(Theme.ink)
            Text("\(typed.count) 件藏品")
                .font(.system(size: 12, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(Theme.ink3)
        }
    }

    // MARK: - 工具行：搜索 / 状态筛选 / 排序

    private var toolRow: some View {
        HStack(spacing: 12) {
            searchField
            filterPills
            Spacer()
            sortMenu
        }
    }

    /// 本页搜索框：只过滤当前类型
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Theme.ink3)
            TextField("搜索\(libraryTitle)…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.ink)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.ink3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 32)
        .background(Theme.well)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Theme.rule, lineWidth: 1))
    }

    /// 状态筛选胶囊：全部 / 进行中 / 已完成 / 待品味
    private var filterPills: some View {
        HStack(spacing: 6) {
            ForEach(StatusFilter.allCases) { filter in
                Button {
                    statusFilter = filter
                } label: {
                    Text(filter.title)
                        .font(Theme.control)
                        .foregroundStyle(statusFilter == filter ? Theme.ink : Theme.ink2)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(statusFilter == filter ? Theme.well : .clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 排序菜单：智能权重 / 最近浏览 / 添加时间 / 标题 / 评分
    private var sortMenu: some View {
        Menu {
            Picker("排序方式", selection: $sortMode) {
                ForEach(SortMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(sortMode.title)
                    .font(Theme.control)
                    .foregroundStyle(Theme.ink)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
            }
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(Theme.well)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Theme.rule, lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - 主体：瀑布网格 / 空态

    @ViewBuilder
    private var content: some View {
        if typed.isEmpty {
            emptyLibrary
        } else if results.isEmpty {
            emptyResults
        } else {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: Theme.cardWidth), spacing: Theme.rowSpacing)],
                spacing: Theme.rowSpacing
            ) {
                ForEach(results) { item in
                    MediaCardView(item: item)
                }
            }
            .padding(.vertical, 4)   // 给悬停浮起留出余量
            .padding(.bottom, 44)
        }
    }

    /// 空库：引导收录第一件
    private var emptyLibrary: some View {
        VStack(spacing: 14) {
            Image(systemName: type.systemImage)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Theme.amber)
            Text("还没有\(type.rawValue)藏品")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.ink)
            Button {
                appState.showingAdd = true
            } label: {
                Text("收录第一件")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.amberOn)
                    .padding(.horizontal, 20)
                    .frame(height: 34)
                    .background(Theme.amberBtn)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }

    /// 搜索 / 筛选无结果：一键清除条件
    private var emptyResults: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(Theme.ink3)
            Text("没有匹配的藏品")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink2)
            Button("清除搜索与筛选") {
                query = ""
                statusFilter = .all
            }
            .font(Theme.control)
            .foregroundStyle(Theme.amber)
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }

    // MARK: - 排序

    /// 按当前排序方式排序
    private func sorted(_ xs: [MediaItem]) -> [MediaItem] {
        switch sortMode {
        case .smart:
            // 智能权重：进行中优先（内部按最近品味倒序），
            // 其余按评分降序，再按最近浏览 / 添加时间倒序
            return xs.sorted { a, b in
                let aDoing = a.status == .inProgress
                let bDoing = b.status == .inProgress
                if aDoing != bDoing { return aDoing }
                if aDoing {
                    return (a.lastTastedAt ?? .distantPast) > (b.lastTastedAt ?? .distantPast)
                }
                if a.rating != b.rating { return a.rating > b.rating }
                return (a.lastViewedDate ?? a.dateAdded) > (b.lastViewedDate ?? b.dateAdded)
            }
        case .recent:
            // 最近浏览：看过的按时间倒序，未看过的按添加时间倒序垫底
            return xs.sorted { a, b in
                switch (a.lastViewedDate, b.lastViewedDate) {
                case let (av?, bv?): return av > bv
                case (_?, nil):      return true
                case (nil, _?):      return false
                case (nil, nil):     return a.dateAdded > b.dateAdded
                }
            }
        case .dateAdded:
            return xs.sorted { $0.dateAdded > $1.dateAdded }
        case .title:
            return xs.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .rating:
            // 评分降序，同分按添加时间倒序保证稳定
            return xs.sorted { a, b in
                if a.rating != b.rating { return a.rating > b.rating }
                return a.dateAdded > b.dateAdded
            }
        }
    }
}

// MARK: - 选项枚举

/// 状态筛选：全部 / 进行中 / 已完成 / 待品味
private enum StatusFilter: String, CaseIterable, Identifiable {
    case all
    case inProgress
    case completed
    case planned

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:        return "全部"
        case .inProgress: return "进行中"
        case .completed:  return "已完成"
        case .planned:    return "待品味"
        }
    }

    func matches(_ status: MediaStatus) -> Bool {
        switch self {
        case .all:        return true
        case .inProgress: return status == .inProgress
        case .completed:  return status == .completed
        case .planned:    return status == .planned
        }
    }
}

/// 排序方式：智能权重 / 最近浏览 / 添加时间 / 标题 / 评分
private enum SortMode: String, CaseIterable, Identifiable {
    case smart
    case recent
    case dateAdded
    case title
    case rating

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smart:     return "智能权重"
        case .recent:    return "最近浏览"
        case .dateAdded: return "添加时间"
        case .title:     return "标题"
        case .rating:    return "评分"
        }
    }
}