import SwiftUI

struct ContentView: View {

    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 184, ideal: 204, max: 240)
        } detail: {
            if appState.isHome {
                HomeView()
            } else {
                BookshelfView()
            }
        }
        .sheet(isPresented: $appState.showingAddSheet) {
            AddMediaView()
                .environmentObject(store)
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 560)
        }
    }
}
