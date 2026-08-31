import SwiftUI

/// 顶栏：Logo + Tab 导航 + 全局搜索 + 收录 / 设置入口
///
/// 隐藏标题栏样式下，左侧留白避让系统红绿灯按钮。
struct TopBarView: View {

    var searchFocused: FocusState<Bool>.Binding

    @Environment(AppState.self) private var appState
    @Environment(LibraryStore.self) private var store
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        @Bindable var state = appState

        HStack(spacing: 26) {
            logo
            tabs
            Spacer()
            searchField
            addButton
            settingsButton
        }
        .padding(.leading, 88)   // 避让红绿灯
        .padding(.trailing, 28)
        .frame(height: 60)
    }

    // MARK: - Logo

    private var logo: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(AngularGradient(
                    colors: [
                        Color(red: 0.36, green: 0.51, blue: 0.96),
                        Color(red: 0.60, green: 0.36, blue: 0.96),
                        Color(red: 0.91, green: 0.36, blue: 0.61),
                        Color(red: 0.91, green: 0.64, blue: 0.24),
                        Color(red: 0.26, green: 0.71, blue: 0.51),
                        Color(red: 0.36, green: 0.51, blue: 0.96)
                    ],
                    center: .center
                ))
                .frame(width: 18, height: 18)
            Text("ArtShelf")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.ink)
        }
    }

    // MARK: - Tab 导航

    private var tabs: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    appState.tab = tab
                    appState.closeDetail()
                } label: {
                    Text(tab.title)
                        .font(.system(size: 13, weight: appState.tab == tab ? .semibold : .regular))
                        .foregroundStyle(appState.tab == tab ? Theme.ink : Theme.ink2)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(appState.tab == tab ? Theme.well : .clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 搜索

    private var searchField: some View {
        @Bindable var state = appState
        return HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Theme.ink3)
            TextField("搜索藏品…", text: $state.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.ink)
                .focused(searchFocused)
                .onSubmit(openFirstMatch)
            if state.searchText.isEmpty {
                Text("⌘F")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.ink3)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Theme.rule, lineWidth: 1)
                    )
            } else {
                Button {
                    state.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.ink3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .frame(width: 216, height: 32)
        .background(Theme.well)
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(
                searchFocused.wrappedValue ? Theme.amber.opacity(0.5) : Theme.rule,
                lineWidth: 1
            )
        )
    }

    /// 回车直达第一条结果
    private func openFirstMatch() {
        guard let first = GlobalSearchView.filter(store.items, query: appState.searchText).first else { return }
        store.markViewed(first)
        appState.openDetail(first)
    }

    // MARK: - 收录与设置

    private var addButton: some View {
        Button {
            appState.showingAdd = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.ink2)
                .frame(width: 32, height: 32)
                .background(Theme.well)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help("收录新媒体（⌘N）")
    }

    private var settingsButton: some View {
        Button {
            openSettings()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink2)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .help("设置（⌘,）")
    }
}
