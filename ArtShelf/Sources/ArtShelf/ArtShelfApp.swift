import SwiftUI
import AppKit

@main
struct ArtShelfApp: App {

    @StateObject private var store = DataStore()
    @StateObject private var appState = AppState()
    @ObservedObject private var themeManager = ThemeManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(appState)
                .onAppear { appDelegate.store = store }
                .tint(ArtShelfStyle.accent)
                .frame(minWidth: 980, minHeight: 640)
        }
        .defaultSize(width: 1280, height: 820)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("偏好设置…") {
                    appState.showingSettingsSheet = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .newItem) {
                Button("添加媒体") { appState.showingAddSheet = true }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                Button("搜索") { appState.searchText = "" }
                    .keyboardShortcut("f", modifiers: .command)
            }
        }

        Settings {
            // 系统偏好设置窗口里 @Environment(\.dismiss) 无效，隐藏无反应的关闭按钮
            SettingsView(showsDismissButton: false)
                .preferredColorScheme(themeManager.appearance.colorScheme)
        }
    }
}

/// 应用代理——负责退出前的数据兜底保存
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// 弱引用主窗口使用的 DataStore，主窗口出现时由 ArtShelfApp 注入
    weak var store: DataStore?

    func applicationWillTerminate(_ notification: Notification) {
        // 退出前同步落盘，避免防抖窗口内退出丢失最后一次修改
        store?.flush()
    }
}
