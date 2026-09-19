import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var pushManager: PushNotificationManager

    @State private var mapping = GLPIFieldMapping.loadFromDefaults()
    @State private var relayURLText = UserDefaults.standard.string(forKey: "relay.baseURL") ?? ""
    @State private var relayAPIKey = UserDefaults.standard.string(forKey: "relay.apiKey") ?? ""
    @State private var savedMappingConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Compte") {
                    if let name = auth.currentUserName {
                        LabeledContent("Connecté en tant que", value: name)
                    }
                    LabeledContent("Serveur", value: auth.serverURLText)
                    Button("Se déconnecter", role: .destructive) {
                        Task { await auth.logout() }
                    }
                }

                Section {
                    Toggle("Notifications push", isOn: Binding(
                        get: { pushManager.isEnabled },
                        set: { enabled in
                            Task {
                                if enabled {
                                    await pushManager.enable(glpiUserId: auth.currentUserId)
                                } else {
                                    pushManager.disable()
                                }
                            }
                        }
                    ))
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("GLPI ne pousse pas de notifications nativement : ce réglage envoie le jeton de cet appareil à un petit relais auto-hébergé (dossier backend/glpi-push-relay) qui interroge GLPI et déclenche les notifications APNs.")
                }

                Section("Relais de notifications") {
                    TextField("https://relais.exemple.com", text: $relayURLText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: relayURLText) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "relay.baseURL")
                        }
                    SecureField("Clé API du relais", text: $relayAPIKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: relayAPIKey) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "relay.apiKey")
                        }
                }

                Section {
                    fieldRow("Champ ID", $mapping.idField)
                    fieldRow("Champ Titre", $mapping.titleField)
                    fieldRow("Champ Statut", $mapping.statusField)
                    fieldRow("Champ Priorité", $mapping.priorityField)
                    fieldRow("Champ Date création", $mapping.dateField)
                    fieldRow("Champ Date modification", $mapping.dateModField)
                    fieldRow("Champ Technicien assigné", $mapping.assignedTechnicianField)

                    Button("Enregistrer le mapping des champs") {
                        mapping.saveToDefaults()
                        savedMappingConfirmation = true
                    }
                } header: {
                    Text("Mapping des champs GLPI (avancé)")
                } footer: {
                    Text("Ce sont les identifiants d'options de recherche GLPI (visibles dans l'URL quand vous ajoutez une colonne dans la recherche de tickets sur le site web). Les valeurs par défaut correspondent à une installation standard ; ajustez-les si votre instance a été personnalisée.")
                }
            }
            .navigationTitle("Réglages")
            .alert("Mapping enregistré", isPresented: $savedMappingConfirmation) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    @ViewBuilder
    private func fieldRow(_ label: String, _ binding: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("id", text: binding)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
                .frame(width: 60)
        }
    }
}
