import SwiftUI

struct CommandesRootView: View {
    @EnvironmentObject private var store: CommandesDataStore
    @State private var isShowingFilePicker = false

    var body: some View {
        Group {
            if store.commandes.isEmpty && store.projets.isEmpty {
                CommandesImportPromptView(isShowingFilePicker: $isShowingFilePicker)
            } else {
                CommandesContentView(isShowingFilePicker: $isShowingFilePicker)
            }
        }
        .navigationTitle("Commandes")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.excelWorkbook, .xlsxExtension, .legacyExcelWorkbook, .xlsExtension],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task { await store.importFile(from: url) }
                }
            case .failure(let error):
                store.errorMessage = error.localizedDescription
            }
        }
        .overlay {
            if store.isImporting {
                ProgressView("Lecture du fichier…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .alert(
            "Erreur",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}
