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

            // 始终占位，避免清除按钮出现/消失导致控件栏宽度变化
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
            .opacity(hasActiveFilter ? 1 : 0)
            .disabled(!hasActiveFilter)
            .allowsHitTesting(hasActiveFilter)
            .accessibilityHidden(!hasActiveFilter)
            .help("清除筛选条件")
        }
        // 无底、无横向内边距——筛选控件簇直接嵌在页眉右侧，由页眉容器提供留白
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                isActive: appState.selectedStatus != nil,
                textMinWidth: 40
            )
        }
        .menuStyle(.borderlessButton)
        // borderlessButton 的 Menu 会用 tint 给 label 上色，盖过内部的 foregroundStyle——
        // 未激活时把 tint 压回墨色，激活时才落朱砂
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
                textMinWidth: 58
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

    /// 标题区的最小宽度，避免切换选项时文字宽度变化导致整个控件栏抖动
    var textMinWidth: CGFloat = 0

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10.5, weight: .medium))
            Text(title)
                .font(ArtShelfStyle.control)
                .lineLimit(1)
                .frame(minWidth: textMinWidth, alignment: .leading)
            Image(systemName: "chevron.down")
                .font(.system(size: 7.5, weight: .bold))
                .opacity(0.5)
        }
        .foregroundStyle(isActive ? ArtShelfStyle.accent : ArtShelfStyle.ink)
        .padding(.horizontal, 10)
        .frame(height: 26)
        // 默认无底——只有文字与图标；悬停给一层淡灰底，选中才落朱砂浅底
        .background {
            if isActive {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(ArtShelfStyle.accentWash)
            } else if isHovered {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(ArtShelfStyle.hoverFill)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHovered = hovering }
        }
    }
}
