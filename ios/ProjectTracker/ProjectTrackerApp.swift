import SwiftUI

@main
struct ProjectTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    AuthManager.shared.handleRedirect(url: url)
                }
        }
    }
}
