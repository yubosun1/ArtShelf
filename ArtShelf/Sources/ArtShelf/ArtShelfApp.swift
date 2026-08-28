import SwiftUI

@main
struct ArtShelfApp: App {

    @StateObject private var store = DataStore()
    @StateObject private var appState = AppState()
    @ObservedObject private var themeManager = ThemeManager.shared

    init() {
        // 自动自愈：清理此前因 NSScroller 异常 swizzle 导致系统持久化的错误 NSSplitView 隐藏状态
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys {
            if key.contains("NSSplitView") {
                defaults.removeObject(forKey: key)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(appState)
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
            SettingsView()
                .preferredColorScheme(themeManager.appearance.colorScheme)
        }
    }
}
