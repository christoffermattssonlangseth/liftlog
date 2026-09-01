import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        TabView {
            LogView()
                .tabItem { Label("Log", systemImage: "plus.circle.fill") }
            HistoryView()
                .tabItem { Label("History", systemImage: "list.bullet") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
