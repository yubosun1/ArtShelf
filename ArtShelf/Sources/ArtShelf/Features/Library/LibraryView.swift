import SwiftUI

/// 库页：片库 / 唱片 / 书架三 Tab 共用的瀑布网格
///
/// 顶部为库名 + 藏品计数，工具行为状态筛选胶囊与排序菜单（本页搜索已移除，
/// 检索统一走顶栏全局搜索）；主体是恒定列宽的封面网格：列宽 / 间距固定，列数随
/// 容器宽度取整。筛选 / 排序均为内存过滤（`typeRaw` 私有，不写 #Predicate）。
/// 空库时引导收录，筛选无结果时提示清除条件。
struct LibraryView: View {

    let type: MediaType

    @Environment(AppState.self) private var appState
    @Environment(LibraryStore.self) private var store

    @State private var statusFilter: StatusFilter = .all
    @State private var sortMode: SortMode = .dateAdded
    /// 网格可用宽度（随窗口变化，驱动列数计算）
    @State private var gridWidth: CGFloat = 0

    /// 网格间距：比「此刻」精选行（rowSpacing 20）松一档，库页全量陈列需要更多呼吸
    private static let gridSpacing: CGFloat = 24

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

    /// 状态筛选 + 排序后的展示结果
    private var results: [MediaItem] {
        sorted(typed.filter { statusFilter.matches($0.status) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                    .padding(.top, Theme.sectionSpacing)
                    .padding(.bottom, 28)
                content
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                gridWidth = width
            }
            // 注意：测量必须在水平内边距之前，否则 gridWidth 会多算 80pt 导致列数高估、网格溢出
            .padding(.horizontal, Theme.contentPadding)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - 标题行：库名 + 计数居左，筛选胶囊与排序菜单靠右同排

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(libraryTitle)
                .font(Theme.sectionTitle)
                .foregroundStyle(Theme.ink)
            Text("\(typed.count) 件藏品")
                .font(.system(size: 12, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(Theme.ink3)
            Spacer()
            filterPills
            sortMenu
        }
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

    /// 排序菜单：最近浏览 / 添加时间 / 标题 / 评分
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
                columns: gridColumns,
                spacing: Self.gridSpacing
            ) {
                ForEach(results) { item in
                    MediaCardView(item: item)
                }
            }
            // 钉住前导对齐：fixed 列网格在多余空间里会把列组居中，
            // frame(maxWidth:alignment:) 对此无效，必须显式给定列组总宽再钉左
            .frame(width: gridContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)   // 给悬停浮起留出余量
            .padding(.bottom, 44)
        }
    }

    /// 恒定列宽网格：列数 = max(1, ⌊(可用宽 + 间距) / (列宽 + 间距)⌋)，
    /// 列宽与间距取 Theme 令牌，窗口缩放时仅列数变化、卡片尺寸恒定
    private var columnCount: Int {
        max(1, Int(floor((gridWidth + Self.gridSpacing) / (Theme.cardWidth + Self.gridSpacing))))
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(Theme.cardWidth), spacing: Self.gridSpacing), count: columnCount)
    }

    /// 列组总宽（列宽×列数 + 间距），用于把网格显式钉到容器前导缘
    private var gridContentWidth: CGFloat {
        CGFloat(columnCount) * Theme.cardWidth + CGFloat(max(0, columnCount - 1)) * Self.gridSpacing
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

    /// 筛选无结果：一键清除条件
    private var emptyResults: some View {
        VStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(Theme.ink3)
            Text("没有符合筛选条件的藏品")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink2)
            Button("清除筛选") {
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

/// 排序方式：最近浏览 / 添加时间 / 标题 / 评分（默认添加时间）
private enum SortMode: String, CaseIterable, Identifiable {
    case recent
    case dateAdded
    case title
    case rating

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent:    return "最近浏览"
        case .dateAdded: return "添加时间"
        case .title:     return "标题"
        case .rating:    return "评分"
        }
    }
}