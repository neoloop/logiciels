import SwiftUI
import SwiftData

@main
struct DiveLogApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Dive.self)
    }
}
