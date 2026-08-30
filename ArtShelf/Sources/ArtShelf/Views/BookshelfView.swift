import SwiftUI

struct BookshelfView: View {

    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState

    private var filteredItems: [MediaItem] {
        appState.filteredItems(from: store)
    }

    /// 自适应等宽网格列
    private let columns = [
        GridItem(
            .adaptive(minimum: ArtShelfStyle.cardWidth, maximum: ArtShelfStyle.cardWidth),
            spacing: ArtShelfStyle.gridSpacing,
            alignment: .top
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            PaperRule()

            if filteredItems.isEmpty {
                emptyState
            } else {
                grid
            }
        }
        .background(ArtShelfStyle.paper)
        .sheet(item: $appState.detailItem) { item in
            DetailView(item: item)
                .environmentObject(store)
                .environmentObject(appState)
        }
    }

    // MARK: - 页眉

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(navigationTitle)
                    .font(ArtShelfStyle.pageTitle)
                    .foregroundStyle(ArtShelfStyle.ink)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(ArtShelfStyle.inkSecondary)
            }

            Spacer(minLength: 16)

            LibraryFilterBar()
        }
        .padding(.horizontal, ArtShelfStyle.contentPadding)
        .padding(.top, 36)
        .padding(.bottom, 16)
    }

    private var isMusicCategory: Bool {
        appState.selectedCategory == .music
    }

    private var rowSpacing: CGFloat {
        isMusicCategory ? 24 : ArtShelfStyle.rowSpacing
    }

    private var grid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: rowSpacing) {
                ForEach(filteredItems) { item in
                    libraryCard(item)
                }
            }
            .padding(.horizontal, ArtShelfStyle.contentPadding)
            .padding(.vertical, ArtShelfStyle.contentPadding)
            .animation(.easeOut(duration: 0.2), value: filteredItems.map(\.id))
        }
        .hideScrollIndicators()
    }

    @ViewBuilder
    private func libraryCard(_ item: MediaItem) -> some View {
        if appState.selectedSort == .custom {
            MediaCardView(item: item)
                .draggable(item.id.uuidString)
                .dropDestination(for: String.self) { values, _ in
                    guard let rawID = values.first,
                          let sourceID = UUID(uuidString: rawID),
                          sourceID != item.id else { return false }
                    withAnimation(.easeOut(duration: 0.2)) {
                        store.moveCustomItem(id: sourceID, before: item.id)
                    }
                    return true
                }
        } else {
            MediaCardView(item: item)
        }
    }

    private var navigationTitle: String {
        appState.selectedTag ?? appState.selectedCategory?.rawValue ?? "全部收藏"
    }

    private var subtitle: String {
        let countUnit: String
        if appState.selectedCategory == .music {
            countUnit = "张唱片"
        } else if appState.selectedCategory == .movie {
            countUnit = "部影视"
        } else if appState.selectedCategory == .book {
            countUnit = "本书籍"
        } else {
            countUnit = "项"
        }
        var parts = ["共 \(filteredItems.count) \(countUnit)"]
        if let status = appState.selectedStatus {
            parts.append(appState.statusLabel(for: status))
        }
        if appState.selectedTimeFilter != .all {
            parts.append(appState.selectedTimeFilter.rawValue)
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: emptyIconName)
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(ArtShelfStyle.accent.opacity(0.8))
                .padding(.bottom, 4)

            Text(emptyTitle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ArtShelfStyle.ink)

            Text(emptyMessage)
                .font(.system(size: 13))
                .foregroundStyle(ArtShelfStyle.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            Button {
                appState.showingAddSheet = true
            } label: {
                Label("添加收藏", systemImage: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(ArtShelfStyle.accent)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var isFiltering: Bool {
        appState.selectedCategory != nil
            || appState.selectedTag != nil
            || appState.selectedTimeFilter != .all
            || appState.selectedStatus != nil
    }

    private var emptyIconName: String {
        if !appState.searchText.isEmpty { return "magnifyingglass" }
        if let cat = appState.selectedCategory {
            switch cat {
            case .movie: return "film.stack"
            case .music: return "opticaldisc"
            case .book:  return "books.vertical"
            }
        }
        return "square.stack.3d.up"
    }

    private var emptyTitle: String {
        if !appState.searchText.isEmpty { return "没有匹配的收藏" }
        if isFiltering { return "当前筛选暂无内容" }
        return "书架还是空的"
    }

    private var emptyMessage: String {
        if !appState.searchText.isEmpty { return "请尝试更换搜索关键词，或清除筛选条件。" }
        if isFiltering { return "切换其他分类，或添加新的媒体收藏。" }
        return "把你看过的电影、在听的专辑、想读的书，都珍藏在这里。"
    }
}
