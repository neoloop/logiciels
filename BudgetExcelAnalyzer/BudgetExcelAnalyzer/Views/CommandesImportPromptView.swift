import SwiftUI

struct CommandesImportPromptView: View {
    @Binding var isShowingFilePicker: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cart")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Importe le fichier Commandes")
                .font(.title2.bold())
            Text("""
            Choisis un fichier Excel (.xlsx) avec une feuille "Expression-<service>" par \
            service (les commandes) et une feuille "PPI" (les projets pluriannuels).
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
