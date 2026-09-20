import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var store: ProjectStore

    var body: some View {
        Form {
            Section("Compte") {
                if let name = auth.accountName {
                    LabeledContent("Connecté", value: name)
                }
                Button("Se déconnecter", role: .destructive) { auth.signOut() }
            }
            Section("Synchronisation") {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Label("Synchroniser maintenant", systemImage: "arrow.triangle.2.circlepath")
                }
                if store.isSyncing {
                    ProgressView()
                }
                if let error = store.syncError {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }
            }
        }
        .navigationTitle("Réglages")
    }
}
