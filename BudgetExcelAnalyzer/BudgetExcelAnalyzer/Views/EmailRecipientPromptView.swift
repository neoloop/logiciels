import SwiftUI

struct EmailRecipientPromptView: View {
    @Binding var email: String
    @Environment(\.dismiss) private var dismiss
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Destinataire") {
                    TextField("chef.service@exemple.fr", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Envoyer par email")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Suivant") { onConfirm() }
                        .disabled(!email.contains("@"))
                }
            }
        }
        .presentationDetents([.height(220)])
    }
}
