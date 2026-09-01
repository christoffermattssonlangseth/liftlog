import SwiftUI

@main
struct LiftLogApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .task { await store.load() }
        }
    }
}
