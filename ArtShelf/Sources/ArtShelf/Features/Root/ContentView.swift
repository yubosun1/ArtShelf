import SwiftUI
import AppKit

/// 根视图：顶栏 + Tab 内容区 + 详情整版 + 全局搜索浮层
struct ContentView: View {

    @Environment(AppState.self) private var appState
    @Environment(LibraryStore.self) private var store
    @FocusState private var searchFocused: Bool
    @State private var showLoadFailure = false

    var body: some View {
        @Bindable var state = appState

        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                TopBarView(searchFocused: $searchFocused)
                Rectangle().fill(Theme.rule).frame(height: 1)
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // 全局搜索结果浮层（Spotlight 式）
            if !state.searchText.isEmpty {
                GlobalSearchView()
                    .padding(.top, 64)
                    .transition(.opacity)
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
        .animation(.easeOut(duration: 0.18), value: state.detailItemID == nil)
        .animation(.easeOut(duration: 0.12), value: state.searchText.isEmpty)
        .onChange(of: appState.searchFocusTick) { _, _ in searchFocused = true }
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

    /// Esc 层级：先清搜索，再关详情
    @ViewBuilder
    private var escHandlers: some View {
        if !appState.searchText.isEmpty {
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
