import SwiftUI

@main
struct BudgetExcelAnalyzerApp: App {
    @StateObject private var store = BudgetDataStore()
    @StateObject private var commandesStore = CommandesDataStore()
    @StateObject private var seditStore = SeditDataStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(commandesStore)
                .environmentObject(seditStore)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await store.autoRefreshIfPossible() }
            Task { await commandesStore.autoRefreshIfPossible() }
            Task { await seditStore.autoRefreshIfPossible() }
        }
    }
}
