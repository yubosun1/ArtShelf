import SwiftUI

struct LibraryFilterBar: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: DataStore

    private var hasActiveFilter: Bool {
        appState.selectedStatus != nil || appState.selectedTimeFilter != .all
    }

    var body: some View {
        HStack(spacing: 7) {
            statusMenu
            timeMenu

            ArtShelfStyle.rule
                .frame(width: 1, height: 16)
                .padding(.horizontal, 3)

            sortMenu

            Spacer(minLength: 8)

            if hasActiveFilter {
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        appState.clearBrowseFilters()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                        Text("清除")
                            .font(ArtShelfStyle.control)
                    }
                    .foregroundStyle(ArtShelfStyle.inkSecondary)
                    .padding(.horizontal, 9)
                    .frame(height: 26)
                    .wellBackground()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("清除筛选条件")
            }
        }
        .padding(.horizontal, ArtShelfStyle.contentPadding)
        .padding(.vertical, 9)
        .background(ArtShelfStyle.surface)
    }

    private var statusMenu: some View {
        Menu {
            Button("全部状态") { appState.selectedStatus = nil }
            Divider()
            ForEach(MediaStatus.allCases, id: \.self) { status in
                Button {
                    appState.selectedStatus = status
                } label: {
                    Label(appState.compactStatusLabel(for: status), systemImage: status.iconName)
                }
            }
        } label: {
            FilterMenuLabel(
                icon: appState.selectedStatus?.iconName ?? "circle.dashed",
                title: appState.selectedStatus.map { appState.compactStatusLabel(for: $0) } ?? "状态",
                isActive: appState.selectedStatus != nil
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("按状态筛选")
    }

    private var timeMenu: some View {
        Menu {
            ForEach(TimeFilter.allCases) { filter in
                Button {
                    appState.selectedTimeFilter = filter
                } label: {
                    Label(filter.rawValue, systemImage: filter.iconName)
                }
            }
        } label: {
            FilterMenuLabel(
                icon: appState.selectedTimeFilter == .all ? "clock" : appState.selectedTimeFilter.iconName,
                title: appState.selectedTimeFilter == .all ? "时间" : appState.selectedTimeFilter.rawValue,
                isActive: appState.selectedTimeFilter != .all
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("按最近浏览时间筛选")
    }

    private var sortMenu: some View {
        Menu {
            ForEach(LibrarySortOption.allCases) { option in
                Button {
                    selectSort(option)
                } label: {
                    Label(option.rawValue, systemImage: option.iconName)
                }
            }
        } label: {
            FilterMenuLabel(
                icon: appState.selectedSort.iconName,
                title: appState.selectedSort.rawValue,
                isActive: appState.selectedSort != .smart
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("更改排序方式")
    }

    private func selectSort(_ option: LibrarySortOption) {
        if option == .custom && appState.selectedSort != .custom {
            store.prepareCustomOrder(from: appState.filteredItems(from: store))
        }
        withAnimation(.easeOut(duration: 0.18)) {
            appState.selectedSort = option
        }
    }
}

private struct FilterMenuLabel: View {
    let icon: String
    let title: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10.5, weight: .medium))
            Text(title)
                .font(ArtShelfStyle.control)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 7.5, weight: .bold))
                .opacity(0.5)
        }
        .foregroundStyle(isActive ? ArtShelfStyle.accent : ArtShelfStyle.ink)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background {
            RoundedRectangle(cornerRadius: ArtShelfStyle.controlRadius, style: .continuous)
                .fill(isActive ? ArtShelfStyle.accentWash : ArtShelfStyle.well)
        }
        .contentShape(Rectangle())
    }
}
