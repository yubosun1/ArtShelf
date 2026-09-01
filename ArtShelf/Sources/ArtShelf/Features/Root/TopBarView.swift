import SwiftUI

/// 顶栏：Logo + Tab 导航 + 全局搜索（结果浮层锚定搜索框正下方）+ 收录 / 设置入口
///
/// 上方已有独立标题条（ContentView），红绿灯不再与本行争位；
/// 左右留白与内容区同为 40，构成统一的左轴。
struct TopBarView: View {

    var searchFocused: FocusState<Bool>.Binding

    @Environment(AppState.self) private var appState
    @Environment(LibraryStore.self) private var store
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        @Bindable var state = appState

        HStack(spacing: 28) {
            logo
            tabs
            Spacer()
            searchField
                .overlay(alignment: .bottomTrailing) {
                    // 结果浮层锚定搜索框正下方：右缘对齐，顶缘距框底 8pt；详情整版打开时不渲染
                    if !state.searchText.isEmpty, state.detailItemID == nil {
                        GlobalSearchView()
                            .alignmentGuide(.bottom) { $0[.top] - 8 }
                            .transition(.opacity)
                    }
                }
            addButton
            settingsButton
        }
        .padding(.horizontal, 40)   // 与内容区 Theme.contentPadding 同轴（反馈：库页左缘须与顶栏对齐）
        .frame(height: 60)
        .background(Theme.titlebar)
    }

    // MARK: - Logo

    private var logo: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(AngularGradient(
                    colors: Theme.prismColors,
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
        let placeholder = store.items.isEmpty ? "搜索藏品…" : "搜索 \(store.items.count) 件藏品…"
        return HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Theme.ink3)
            TextField(placeholder, text: $state.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.ink)
                .focused(searchFocused)
                .onSubmit(openFirstMatch)
            if state.searchText.isEmpty {
                Text("⌘F")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.ink3)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Theme.panel.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
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
                searchFocused.wrappedValue ? Theme.amber.opacity(0.55) : Theme.rule,
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
