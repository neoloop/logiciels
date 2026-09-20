import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var config: AppConfig
    @EnvironmentObject private var authService: GraphAuthService

    @State private var errorMessage: String?
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Compte Microsoft") {
                    if authService.isSignedIn {
                        LabeledContent("Connecté", value: authService.accountDisplayName ?? "")
                        Button("Se déconnecter", role: .destructive) {
                            try? authService.signOut()
                        }
                    } else {
                        Button("Se connecter à Microsoft 365") {
                            Task { await signIn() }
                        }
                        .disabled(!config.isConfigured || isWorking)
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }

                Section {
                    TextField("Client ID (Azure AD)", text: $config.clientId)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    TextField("Tenant ID (ou 'organizations')", text: $config.tenantId)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                } header: {
                    Text("Inscription Azure AD")
                } footer: {
                    Text("Voir le README du projet pour créer l'inscription d'application dans Azure Portal. L'URI de redirection à déclarer est : \(config.redirectUri)")
                }
                .onChange(of: config.clientId) { _, _ in reconfigure() }
                .onChange(of: config.tenantId) { _, _ in reconfigure() }

                Section {
                    TextField("Base du lecteur (ex: /me/drive)", text: $config.driveBasePath)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    TextField("Chemin du fichier .json", text: $config.jsonFilePath)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                } header: {
                    Text("Fichier des demandes (OneDrive / SharePoint)")
                } footer: {
                    Text("Le même fichier JSON que celui utilisé par les pages web. S'il n'existe pas encore, il est créé automatiquement lors du premier enregistrement.")
                }

                Section {
                    TextField("Votre nom", text: $config.validatorName)
                    TextField("Votre email", text: $config.validatorEmail)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .keyboardType(.emailAddress)
                } header: {
                    Text("Valideur (vous)")
                } footer: {
                    Text("Cet email est mis en copie du mail envoyé au bénéficiaire, et sera la boîte qui recevra le PDF signé en retour.")
                }
            }
            .navigationTitle("Réglages")
        }
    }

    private func reconfigure() {
        try? authService.configure(with: config)
    }

    private func signIn() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            _ = try await authService.acquireToken(scopes: config.graphScopes)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppConfig.shared)
        .environmentObject(GraphAuthService.shared)
}
