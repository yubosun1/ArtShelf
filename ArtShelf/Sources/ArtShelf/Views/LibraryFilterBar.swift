import SwiftUI

struct LibraryFilterBar: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: DataStore

    private var hasActiveFilter: Bool {
        appState.selectedStatus != nil || appState.selectedTimeFilter != .all
    }

    var body: some View {
        HStack(spacing: 8) {
            statusMenu
            timeMenu

            Rectangle()
                .fill(ArtShelfStyle.rule)
                .frame(width: 1, height: 16)
                .padding(.horizontal, 2)

            sortMenu

            if hasActiveFilter {
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        appState.clearBrowseFilters()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                        Text("重置")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .foregroundStyle(ArtShelfStyle.inkSecondary)
                    .padding(.horizontal, 9)
                    .frame(height: 28)
                    .background(
                        Capsule()
                            .fill(ArtShelfStyle.well)
                    )
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .help("清除筛选条件")
            }
        }
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
                icon: appState.selectedStatus?.iconName ?? "line.3.horizontal.decrease.circle",
                title: appState.selectedStatus.map { appState.compactStatusLabel(for: $0) } ?? "状态",
                isActive: appState.selectedStatus != nil,
                textMinWidth: 38
            )
        }
        .menuStyle(.borderlessButton)
        .tint(appState.selectedStatus != nil ? ArtShelfStyle.accent : ArtShelfStyle.ink)
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
                isActive: appState.selectedTimeFilter != .all,
                textMinWidth: 52
            )
        }
        .menuStyle(.borderlessButton)
        .tint(appState.selectedTimeFilter != .all ? ArtShelfStyle.accent : ArtShelfStyle.ink)
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
                isActive: appState.selectedSort != .smart,
                textMinWidth: 52
            )
        }
        .menuStyle(.borderlessButton)
        .tint(appState.selectedSort != .smart ? ArtShelfStyle.accent : ArtShelfStyle.ink)
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
    var textMinWidth: CGFloat = 0

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))

            Text(title)
                .font(.system(size: 12, weight: isActive ? .semibold : .medium))
                .lineLimit(1)
                .frame(minWidth: textMinWidth, alignment: .leading)

            Image(systemName: "chevron.down")
                .font(.system(size: 7.5, weight: .semibold))
                .opacity(0.45)
        }
        .foregroundStyle(isActive ? ArtShelfStyle.accent : ArtShelfStyle.ink)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isActive ? ArtShelfStyle.accentWash : (isHovered ? ArtShelfStyle.wellHover : ArtShelfStyle.well))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(isActive ? ArtShelfStyle.accent.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHovered = hovering }
        }
    }
}
