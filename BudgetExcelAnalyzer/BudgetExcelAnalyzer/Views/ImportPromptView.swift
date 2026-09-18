import SwiftUI

struct ImportPromptView: View {
    @Binding var isShowingFilePicker: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tablecells")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Importe ton classeur budget")
                .font(.title2.bold())
            Text("""
            Choisis un fichier Excel (.xlsx) depuis l'app Fichiers, notamment ton dossier \
            OneDrive. Le classeur doit contenir une feuille "Transactions" (Date, Catégorie, \
            Montant) et une feuille "Budget" (Catégorie, Budget).
            """)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            Button {
                isShowingFilePicker = true
            } label: {
                Label("Choisir un fichier", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
        }
        .padding()
    }
}
