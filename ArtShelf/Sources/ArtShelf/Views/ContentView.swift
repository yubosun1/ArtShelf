import SwiftUI

struct ContentView: View {

    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 198, max: 230)
        } detail: {
            BookshelfView()
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            appState.showingAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .help("添加收藏 (⌘N)")
                    }
                }
        }

        .searchable(text: $appState.searchText, placement: .toolbar, prompt: "搜索收藏")
        .sheet(isPresented: $appState.showingAddSheet) {
            AddMediaView()
                .environmentObject(store)
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 560)
        }
    }
}
