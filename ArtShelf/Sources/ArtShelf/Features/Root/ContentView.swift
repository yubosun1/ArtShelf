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

/// 窗口 chrome：全尺寸内容视图 + 红绿灯下移与单行顶栏同轴
///
/// hiddenTitleBar 下内容默认从 titlebar 下方开始排、红绿灯钉在窗口顶，
/// 与顶栏错位两行；这里切全尺寸内容视图（内容延伸到窗口顶，titlebar 透明覆盖）
/// 并忽略顶部安全区（ContentView.ignoresSafeArea），顶栏 48pt 单行排布，
/// 三个窗口按钮的中心挪到窗口顶下 21pt（容器内可达的最低位置），
/// 与顶栏内容中心（24pt）对齐到视觉不可分辨的 3pt 以内。
@MainActor
enum WindowChrome {

    /// 按钮中心距窗口顶的目标值：容器高 28pt，按钮完整留在容器内的最低位置是 21pt
    /// （按钮半径 7pt，中心 21pt 时底边恰好贴容器底）；与顶栏内容中心（28pt）视差可接受
    private static let targetCenterFromTop: CGFloat = 21

    /// 通知观察者令牌（保留以防自动移除；.main 队列派发，主线程执行）
    nonisolated(unsafe) private static var observers: [NSObjectProtocol] = []

    /// 启动时调用：设置窗口样式，并挂缩放监听（系统会在缩放时复位按钮位置）
    static func apply() {
        guard observers.isEmpty else { return }
        for name: Notification.Name in [NSWindow.didResizeNotification, NSWindow.didBecomeKeyNotification] {
            observers.append(NotificationCenter.default.addObserver(
                forName: name, object: nil, queue: .main
            ) { note in
                guard let window = note.object as? NSWindow else { return }
                MainActor.assumeIsolated { offsetButtons(of: window) }
            })
        }
        // onAppear 时窗口已存在，但 contentView 挂接可能晚一拍，延后一次兜底
        DispatchQueue.main.async { applyToWindows() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { applyToWindows() }
    }

    private static func applyToWindows() {
        for window in NSApplication.shared.windows where window.styleMask.contains(.titled) {
            if !window.styleMask.contains(.fullSizeContentView) {
                window.styleMask.insert(.fullSizeContentView)
            }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            offsetButtons(of: window)
        }
    }

    /// 红绿灯中心挪到窗口顶下 21pt（按钮半径约 7pt，完整留在 28pt 高容器内的最低位置）
    private static func offsetButtons(of window: NSWindow) {
        for kind: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            guard let button = window.standardWindowButton(kind),
                  let container = button.superview else { continue }
            // AppKit 坐标 y 向上；容器顶边即窗口顶边
            let targetMidY = container.bounds.height - targetCenterFromTop
            let dy = targetMidY - button.frame.midY
            if abs(dy) > 0.5 {
                button.frame.origin.y += dy
            }
        }
    }
}
