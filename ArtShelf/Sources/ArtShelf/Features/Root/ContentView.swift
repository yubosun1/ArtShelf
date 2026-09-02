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
                TopBarView(searchFocused: $searchFocused)
                    .zIndex(1)   // 搜索浮层向下溢出顶栏，需压过内容区（顶栏渐变已收口，无发丝线）
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
        .ignoresSafeArea()   // 全尺寸内容视图下顶掉 titlebar 安全区，内容从窗口顶 0 开始
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
            // 单行 chrome：全尺寸内容视图 + 红绿灯下移与顶栏同轴
            WindowChrome.apply()
            // 库加载失败时提示（文案由迁移器按原因给出：损坏已备份 / 版本过新未动原文件）
            showLoadFailure = store.loadFailureMessage != nil
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            store.flush()
        }
        .alert("数据未能加载", isPresented: $showLoadFailure) {
            Button("好", role: .cancel) {}
        } message: {
            Text(store.loadFailureMessage ?? "")
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

    /// Esc 层级：详情打开时优先关详情，否则清搜索（搜索浮层仅在详情未打开时渲染，此处口径一致）
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

/// 窗口 chrome：全尺寸内容视图 + 透明 titlebar
///
/// 启用全尺寸内容视图（内容延伸到窗口顶，titlebar 透明覆盖）
/// 并忽略顶部安全区（ContentView.ignoresSafeArea），由 TopBarView 顶部预留 28pt
/// 作为系统红绿灯呼吸区与窗口拖拽区，Tab 导航自然位于其下方。
@MainActor
enum WindowChrome {

    static func apply() {
        applyToWindows()
        DispatchQueue.main.async { applyToWindows() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { applyToWindows() }
    }

    private static func applyToWindows() {
        for window in NSApplication.shared.windows where window.styleMask.contains(.titled) {
            if !window.styleMask.contains(.fullSizeContentView) {
                window.styleMask.insert(.fullSizeContentView)
            }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
        }
    }
}
