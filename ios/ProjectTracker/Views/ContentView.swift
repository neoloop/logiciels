import SwiftUI

struct ContentView: View {
    @StateObject private var auth = AuthManager.shared
    @StateObject private var store = ProjectStore()

    var body: some View {
        Group {
            if auth.isSignedIn {
                MainTabView()
                    .environmentObject(store)
                    .environmentObject(auth)
                    .task { await store.refresh() }
            } else {
                SignInView()
                    .environmentObject(auth)
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { ProjectListView() }
                .tabItem { Label("Projets", systemImage: "list.bullet") }
            NavigationStack { GanttView() }
                .tabItem { Label("Diagramme", systemImage: "chart.bar.xaxis") }
            NavigationStack { SettingsView() }
                .tabItem { Label("Réglages", systemImage: "gear") }
        }
    }
}
