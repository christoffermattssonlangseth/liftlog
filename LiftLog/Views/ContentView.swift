import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        TabView {
            LogView()
                .tabItem { Label("Log", systemImage: "plus.circle.fill") }
            HistoryView()
                .tabItem { Label("History", systemImage: "list.bullet") }
            TrendsView()
                .tabItem { Label("Trends", systemImage: "chart.line.uptrend.xyaxis") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Theme.accent)
    }
}

