import SwiftUI

@main
struct ArtShelfApp: App {

    @StateObject private var store = DataStore()
    @StateObject private var appState = AppState()

    init() {
        ScrollbarKiller.install()
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
            CommandGroup(replacing: .newItem) {
                Button("添加媒体") { appState.showingAddSheet = true }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                Button("搜索") { appState.searchText = "" }
                    .keyboardShortcut("f", modifiers: .command)
            }
        }
    }
}
