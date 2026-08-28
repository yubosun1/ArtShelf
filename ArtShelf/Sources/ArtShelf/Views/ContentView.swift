import SwiftUI

struct ContentView: View {

    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 184, ideal: 204, max: 240)
        } detail: {
            Group {
                if appState.isHome {
                    HomeView()
                } else {
                    BookshelfView()
                }
            }
            .ignoresSafeArea(.all, edges: .top)
        }
        .sheet(isPresented: $appState.showingAddSheet) {
            AddMediaView()
                .environmentObject(store)
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 560)
        }
    }
}
