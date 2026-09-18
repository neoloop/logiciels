import SwiftUI

struct ImportPromptView: View {
    @Binding var isShowingFilePicker: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tablecells")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Importe ta situation budgétaire")
                .font(.title2.bold())
            Text("""
            Choisis un fichier Excel (.xlsx) depuis l'app Fichiers, notamment ton dossier \
            OneDrive. Il doit s'agir d'un export "Situation Budgétaire" (une ligne par \
            nomenclature, colonnes Article Nat., Groupe Section, Service Gestionnaire, \
            Mt Voté CP, Mt Disponible). Si ton fichier est en .xls, convertis-le d'abord \
            en .xlsx.
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
