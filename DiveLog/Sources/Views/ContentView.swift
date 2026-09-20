import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DiveListView()
                .tabItem {
                    Label("Plongées", systemImage: "water.waves")
                }
            StatsView()
                .tabItem {
                    Label("Statistiques", systemImage: "chart.bar")
                }
        }
    }
}

#Preview {
    ContentView()
}
