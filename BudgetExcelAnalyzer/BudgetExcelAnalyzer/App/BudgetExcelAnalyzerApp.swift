import SwiftUI

@main
struct BudgetExcelAnalyzerApp: App {
    @StateObject private var store = BudgetDataStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await store.autoRefreshIfPossible() }
        }
    }
}
