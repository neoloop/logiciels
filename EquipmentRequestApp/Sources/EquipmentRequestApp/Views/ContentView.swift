import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NewRequestView()
                .tabItem { Label("Nouvelle demande", systemImage: "plus.circle") }

            HistoryView()
                .tabItem { Label("Historique", systemImage: "clock.arrow.circlepath") }

            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gearshape") }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppConfig.shared)
        .environmentObject(GraphAuthService.shared)
}
