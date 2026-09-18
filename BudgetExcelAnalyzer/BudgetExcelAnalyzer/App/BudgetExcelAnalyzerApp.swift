import SwiftUI

@main
struct BudgetExcelAnalyzerApp: App {
    @StateObject private var store = BudgetDataStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
