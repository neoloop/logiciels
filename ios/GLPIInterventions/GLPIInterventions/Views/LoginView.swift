import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Mode de connexion") {
                    Picker("Mode", selection: $auth.connectionMode) {
                        ForEach(ConnectionMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if auth.connectionMode == .direct {
                    Section {
                        Text("Renseignez les informations de connexion à votre instance GLPI (nécessite d'être sur le réseau de l'entreprise ou connecté en VPN). L'App-Token se configure dans Configuration ▸ Générale ▸ API, le User-Token dans vos Préférences ▸ Clés API.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section("Serveur") {
                        TextField("https://glpi.exemple.com", text: $auth.serverURLText)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    Section("Authentification API") {
                        SecureField("App-Token", text: $auth.appToken)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("User-Token", text: $auth.userToken)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                } else {
                    Section {
                        Text("Lecture seule : les données viennent d'un fichier exporté périodiquement depuis GLPI (voir tools/glpi-onedrive-export) et synchronisé sur OneDrive. Fonctionne sans VPN, mais changer un statut ou ajouter un suivi nécessite le mode Direct.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section("Fichier d'export") {
                        TextField("URL du fichier (lien OneDrive)", text: $auth.exportFileURLText)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                if let errorMessage = auth.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button {
                        Task { await auth.connect() }
                    } label: {
                        if auth.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Se connecter")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(auth.isLoading)
                }
            }
            .navigationTitle("Connexion GLPI")
        }
    }
}
