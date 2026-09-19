import Foundation

/// Holds the last imported commandes/projets (a separate file from the budget execution
/// export), with the same local-cache/security-scoped-bookmark pattern as BudgetDataStore.
@MainActor
final class CommandesDataStore: ObservableObject {
    @Published private(set) var commandes: [CommandeLine] = []
    @Published private(set) var projets: [ProjetLine] = []
    @Published private(set) var lastImportDate: Date?
    @Published private(set) var sourceFileName: String?
    @Published var errorMessage: String?
    @Published var isImporting = false

    private static let bookmarkNamespace = "commandes"

    private let snapshotURL: URL = {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("commandes-snapshot.json")
    }()

    init() {
        loadSnapshot()
    }

    /// Services present in the imported commandes/projets, for filter pickers.
    var serviceCodes: [Int] {
        Array(Set(commandes.map(\.serviceCode)).union(projets.map(\.serviceCode))).sorted {
            ServiceDisplayOverrides.sortRank(forServiceCode: $0) < ServiceDisplayOverrides.sortRank(forServiceCode: $1)
        }
    }

    func serviceDisplayName(_ code: Int) -> String {
        let fallback = commandes.first { $0.serviceCode == code }?.serviceLabel ?? "Service \(code)"
        return ServiceDisplayOverrides.displayName(forServiceCode: code, fallback: fallback)
    }

    func commandes(forService serviceCode: Int?) -> [CommandeLine] {
        let filtered = serviceCode.map { code in commandes.filter { $0.serviceCode == code } } ?? commandes
        return filtered.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    func projets(forService serviceCode: Int?) -> [ProjetLine] {
        let filtered = serviceCode.map { code in projets.filter { $0.serviceCode == code } } ?? projets
        return filtered.sorted { $0.nom.localizedCaseInsensitiveCompare($1.nom) == .orderedAscending }
    }

    func importFile(from url: URL) async {
        isImporting = true
        errorMessage = nil
        defer { isImporting = false }

        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try Self.readCoordinated(at: url)
            }.value

            try BookmarkStore.save(url: url, namespace: Self.bookmarkNamespace)

            commandes = result.commandes
            projets = result.projets
            lastImportDate = Date()
            sourceFileName = url.lastPathComponent
            saveSnapshot()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshFromSavedBookmark() async {
        guard let url = BookmarkStore.resolve(namespace: Self.bookmarkNamespace) else {
            errorMessage = "Aucun fichier enregistré. Importe à nouveau ton classeur."
            return
        }
        await importFile(from: url)
    }

    func autoRefreshIfPossible() async {
        guard let url = BookmarkStore.resolve(namespace: Self.bookmarkNamespace) else { return }
        await importFile(from: url)
    }

    nonisolated private static func readCoordinated(at url: URL) throws -> CommandesImportService.ImportResult {
        var coordinatorError: NSError?
        var result: Result<CommandesImportService.ImportResult, Error>?

        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinatorError) { coordinatedURL in
            result = Result { try CommandesImportService.importWorkbook(at: coordinatedURL) }
        }

        if let coordinatorError {
            throw coordinatorError
        }
        guard let result else {
            throw ImportError.cannotOpenFile
        }
        return try result.get()
    }

    // MARK: - Local snapshot persistence

    private struct Snapshot: Codable {
        let commandes: [CommandeLine]
        let projets: [ProjetLine]
        let lastImportDate: Date
        let sourceFileName: String
    }

    private func saveSnapshot() {
        guard let sourceFileName, let lastImportDate else { return }
        let snapshot = Snapshot(commandes: commandes, projets: projets, lastImportDate: lastImportDate, sourceFileName: sourceFileName)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: snapshotURL, options: .atomic)
    }

    private func loadSnapshot() {
        guard let data = try? Data(contentsOf: snapshotURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        commandes = snapshot.commandes
        projets = snapshot.projets
        lastImportDate = snapshot.lastImportDate
        sourceFileName = snapshot.sourceFileName
    }
}
