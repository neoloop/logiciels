import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: BudgetDataStore
    @State private var isShowingFilePicker = false

    var body: some View {
        NavigationStack {
            Group {
                if store.lineItems.isEmpty {
                    ImportPromptView(isShowingFilePicker: $isShowingFilePicker)
                } else {
                    DashboardView(isShowingFilePicker: $isShowingFilePicker)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image("SIS2BLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                        Text("Budget GR SIC")
                            .font(.headline)
                    }
                }
            }
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
}
