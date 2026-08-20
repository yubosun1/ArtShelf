import SwiftUI

struct BookshelfView: View {

    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState

    private var filteredItems: [MediaItem] {
        appState.filteredItems(from: store)
    }

    /// 固定宽度的列——封面宽度一致，书架线才能连成一条。
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
        .navigationTitle(navigationTitle)
        .sheet(item: $appState.detailItem) { item in
            DetailView(item: item)
                .environmentObject(store)
                .environmentObject(appState)
        }
    }

    // MARK: - 页眉

    /// 编辑式页眉：印章 + 宋体大标题 + 小字副题，右侧是筛选控件簇。
    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    SealMark(size: 8)
                    Text(navigationTitle)
                        .font(ArtShelfStyle.pageTitle)
                        .foregroundStyle(ArtShelfStyle.ink)
                }
                Text(subtitle)
                    .font(.system(size: 11))
                    .tracking(0.5)
                    .foregroundStyle(ArtShelfStyle.inkTertiary)
            }
            Spacer(minLength: 16)
            LibraryFilterBar()
        }
        .padding(.horizontal, ArtShelfStyle.contentPadding)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: ArtShelfStyle.rowSpacing) {
                ForEach(filteredItems) { item in
                    libraryCard(item)
                }
            }
            .padding(.horizontal, ArtShelfStyle.contentPadding)
            .padding(.vertical, ArtShelfStyle.contentPadding)
            .animation(.easeOut(duration: 0.2), value: filteredItems.map(\.id))
        }
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
        appState.selectedTag ?? appState.selectedCategory?.rawValue ?? "收藏"
    }

    /// 副题：共 N 项；有状态/时间筛选时追加说明。
    private var subtitle: String {
        var parts = ["共 \(filteredItems.count) 项"]
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
        VStack(spacing: 14) {
            SealMark(size: 9)
            Text(emptyTitle)
                .font(ArtShelfStyle.serifTitle(20))
                .foregroundStyle(ArtShelfStyle.ink)
            Text(emptyMessage)
                .font(ArtShelfStyle.body)
                .foregroundStyle(ArtShelfStyle.inkSecondary)
                .multilineTextAlignment(.center)
            Button {
                appState.showingAddSheet = true
            } label: {
                Label("添加收藏", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
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

    private var emptyTitle: String {
        if !appState.searchText.isEmpty { return "没有匹配的收藏" }
        if isFiltering { return "这一格还空着" }
        return "书架是空的"
    }

    private var emptyMessage: String {
        if !appState.searchText.isEmpty { return "换个关键词，或清除筛选条件。" }
        if isFiltering { return "切换筛选条件，或添加新的收藏。" }
        return "添加一部电影、一张专辑，或一本书。"
    }
}
