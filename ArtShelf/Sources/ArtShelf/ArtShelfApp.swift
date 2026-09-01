import SwiftUI

/// 应用入口（main.swift 调用 `ArtShelfApp.main()`）
@MainActor
struct ArtShelfApp: App {

    @State private var appState = AppState()
    @State private var store = LibraryStore.shared

    init() {
        // 启动时应用外观设置（跟随系统 / 强制浅 / 强制深）
        ThemeSettings.shared.applyAppearance()
    }

    var body: some Scene {
        Window("ArtShelf", id: "main") {
            ContentView()
                .environment(appState)
                .environment(store)
                .frame(minWidth: 1100, idealWidth: 1240, minHeight: 720, idealHeight: 820)
                .background(Theme.bg)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // ⌘N 收录（替换默认的「新建窗口」）
            CommandGroup(replacing: .newItem) {
                Button("收录新媒体…") { appState.showingAdd = true }
                    .keyboardShortcut("n", modifiers: .command)
            }
            // ⌘F 全局搜索
            CommandGroup(after: .textEditing) {
                Button("搜索藏品…") { appState.searchFocusTick += 1 }
                    .keyboardShortcut("f", modifiers: .command)
            }
            // ⌘1–⌘5 切换 Tab
            CommandMenu("前往") {
                ForEach(AppTab.allCases) { tab in
                    Button(tab.title) {
                        appState.tab = tab
                        appState.closeDetail()
                    }
                    .keyboardShortcut(tab.keyEquivalent, modifiers: .command)
                }
            }
        }

        // ⌘, 设置（系统自动挂接快捷键）
        Settings {
            SettingsView()
                .environment(store)
        }
    }
}
