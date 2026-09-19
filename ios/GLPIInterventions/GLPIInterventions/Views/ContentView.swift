import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        Group {
            if auth.isAuthenticated, let repository = auth.repository {
                TabView {
                    TicketListView(repository: repository)
                        .tabItem { Label("Interventions", systemImage: "wrench.and.screwdriver") }

                    SettingsView()
                        .tabItem { Label("Réglages", systemImage: "gearshape") }
                }
            } else {
                LoginView()
            }
        }
        .task { await auth.restoreSessionIfPossible() }
    }
}
