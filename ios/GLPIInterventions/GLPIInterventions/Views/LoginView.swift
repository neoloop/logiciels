import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Renseignez les informations de connexion à votre instance GLPI. L'App-Token se configure dans Configuration ▸ Générale ▸ API, le User-Token dans vos Préférences ▸ Clés API.")
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

                if let errorMessage = auth.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button {
                        Task { await auth.login() }
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
