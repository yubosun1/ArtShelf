import SwiftUI
import AppKit

/// 根视图：顶栏（全局搜索浮层锚定于其搜索框）+ Tab 内容区 + 详情整版
struct ContentView: View {

    @Environment(AppState.self) private var appState
    @Environment(LibraryStore.self) private var store
    @FocusState private var searchFocused: Bool
    @State private var showLoadFailure = false

    var body: some View {
        @Bindable var state = appState

        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                titlebarStrip
                Rectangle().fill(Theme.rule).frame(height: 1)
                TopBarView(searchFocused: $searchFocused)
                    .zIndex(1)   // 搜索浮层向下溢出顶栏，需压过发丝线与内容区
                Rectangle().fill(Theme.rule).frame(height: 1)
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // 详情整版（取代内容区）
            if let itemID = state.detailItemID {
                DetailView(itemID: itemID)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.bg)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .background(escHandlers)
        .suppressAllScrollbars()
        .animation(.easeOut(duration: 0.18), value: state.detailItemID == nil)
        .animation(.easeOut(duration: 0.12), value: state.searchText.isEmpty)
        .onChange(of: appState.searchFocusTick) { _, _ in
            // 详情整版打开时忽略 ⌘F 聚焦信号：搜索框被盖住，聚焦会导致盲输入且吞掉第一次 Esc
            if appState.detailItemID == nil { searchFocused = true }
        }
        .onChange(of: appState.detailItemID) { _, itemID in
            // 详情打开即释放搜索框焦点（理由同上：残留焦点会让盲输入进入被盖住的搜索框）
            if itemID != nil { searchFocused = false }
        }
        .sheet(isPresented: $state.showingAdd) {
            AddMediaView()
        }
        .onAppear {
            // 库文件无法解析时提示（原始文件已备份，未做任何覆盖）
            showLoadFailure = store.loadFailed
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            store.flush()
        }
        .alert("数据文件无法解析", isPresented: $showLoadFailure) {
            Button("好", role: .cancel) {}
        } message: {
            Text("原始文件已备份在 ~/Library/Application Support/ArtShelf/ 中，当前以空库启动。")
        }
    }

    /// 标题条：46pt 高空白条，红绿灯浮于其左上，顶栏因此整体下移一行、logo 得以靠左
    ///（概念稿同位置有居中 ARTSHELF 小字，实拍后按反馈去除，仅保留色条）
    private var titlebarStrip: some View {
        Theme.titlebar
            .frame(height: 46)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch appState.tab {
        case .now:
            NowView()
        case .movies:
            LibraryView(type: .movie)
        case .music:
            LibraryView(type: .music)
        case .books:
            LibraryView(type: .book)
        case .stats:
            StatsView()
        }
    }

    /// Esc 层级：先清搜索，再关详情（搜索浮层仅在详情未打开时渲染，此处口径一致）
    @ViewBuilder
    private var escHandlers: some View {
        if !appState.searchText.isEmpty, appState.detailItemID == nil {
            Button("") { appState.searchText = "" }
                .keyboardShortcut(.escape, modifiers: [])
                .hidden()
        } else if appState.detailItemID != nil {
            Button("") { appState.closeDetail() }
                .keyboardShortcut(.escape, modifiers: [])
                .hidden()
        }
    }
}
