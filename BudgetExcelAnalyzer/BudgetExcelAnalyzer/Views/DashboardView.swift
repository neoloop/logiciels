import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: BudgetDataStore
    @EnvironmentObject private var commandesStore: CommandesDataStore
    @EnvironmentObject private var seditStore: SeditDataStore
    @Binding var isShowingFilePicker: Bool

    @State private var isShowingFolderPicker = false
    @State private var isImportingFolder = false
    @State private var folderImportSummary: String?
    @State private var folderImportError: String?

    var body: some View {
        List {
            Section {
                ForEach(store.services) { service in
                    NavigationLink {
                        ServiceDetailView(service: service)
                    } label: {
                        ServiceRow(summary: service)
                    }
                }
            } header: {
                Label("Services", systemImage: "building.2.fill")
            }

            Section {
                NavigationLink("Toutes nomenclatures, tous services") {
                    ConsolidatedView()
                }
            } header: {
                Label("Consolidation", systemImage: "chart.pie.fill")
            }

            Section {
                NavigationLink("Commandes et projets") {
                    CommandesRootView()
                }
            } header: {
                Label("Commandes", systemImage: "cart.fill")
            }

            if let lastImportDate = store.lastImportDate {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        if let name = store.sourceFileName {
                            Text(name).font(.caption).foregroundStyle(.secondary)
                        }
                        Text("Importé le \(lastImportDate.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .refreshable {
            // Re-reading via the saved bookmark can silently serve a stale cached copy for
            // third-party providers like OneDrive (their file-provider extension doesn't
            // always re-check the server for a bookmarked URL accessed outside the Files
            // app). Reopening the picker goes through the live Files UI, which reliably
            // fetches the current version.
            isShowingFilePicker = true
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        isShowingFilePicker = true
                    } label: {
                        Label("Fichier budget seul", systemImage: "doc")
                    }
                    Button {
                        isShowingFolderPicker = true
                    } label: {
                        Label("Dossier complet (budget, commandes, Sedit)", systemImage: "folder")
                    }
                } label: {
                    Label("Importer", systemImage: "square.and.arrow.down")
                }
            }
        }
        .fileImporter(
            isPresented: $isShowingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let folderURL = urls.first {
                    Task { await importFolder(at: folderURL) }
                }
            case .failure(let error):
                folderImportError = error.localizedDescription
            }
        }
        .overlay {
            if isImportingFolder {
                ProgressView("Analyse du dossier…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .alert(
            "Erreur",
            isPresented: Binding(
                get: { folderImportError != nil },
                set: { if !$0 { folderImportError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(folderImportError ?? "")
        }
        .alert(
            "Import du dossier",
            isPresented: Binding(
                get: { folderImportSummary != nil },
                set: { if !$0 { folderImportSummary = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(folderImportSummary ?? "")
        }
    }

    private func importFolder(at folderURL: URL) async {
        isImportingFolder = true
        defer { isImportingFolder = false }

        let needsAccess = folderURL.startAccessingSecurityScopedResource()
        defer { if needsAccess { folderURL.stopAccessingSecurityScopedResource() } }

        do {
            let classified = try await Task.detached(priority: .userInitiated) {
                try FolderImportService.classifyFiles(in: folderURL)
            }.value

            var found: [String] = []
            var missing: [String] = []

            if let budgetURL = classified.budgetFileURL {
                await store.importFile(from: budgetURL)
                found.append("Budget")
            } else {
                missing.append("Budget")
            }

            if let commandesURL = classified.commandesFileURL {
                await commandesStore.importFile(from: commandesURL)
                found.append("Commandes")
            } else {
                missing.append("Commandes")
            }

            if let seditURL = classified.seditFileURL {
                await seditStore.importFile(from: seditURL)
                found.append("Sedit")
            } else {
                missing.append("Sedit")
            }

            var summary = "Importés : \(found.joined(separator: ", "))."
            if !missing.isEmpty {
                summary += "\nNon trouvés dans le dossier : \(missing.joined(separator: ", "))."
            }
            if !classified.unrecognizedFileNames.isEmpty {
                summary += "\nFichiers non reconnus : \(classified.unrecognizedFileNames.joined(separator: ", "))."
            }
            folderImportSummary = summary
        } catch {
            folderImportError = error.localizedDescription
        }
    }
}
