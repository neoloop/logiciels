import Foundation

/// Central app state: holds the last imported budget lines and a local JSON snapshot so
/// the dashboard has data immediately on relaunch without re-reading the (possibly
/// remote, OneDrive-backed) source file.
@MainActor
final class BudgetDataStore: ObservableObject {
    @Published private(set) var lineItems: [BudgetLineItem] = []
    @Published private(set) var lastImportDate: Date?
    @Published private(set) var sourceFileName: String?
    @Published var errorMessage: String?
    @Published var isImporting = false

    private let snapshotURL: URL = {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("budget-snapshot.json")
    }()

    init() {
        loadSnapshot()
    }

    /// Services present in the imported file, detected automatically (not hardcoded),
    /// sorted by code.
    var services: [ServiceSummary] {
        let grouped = Dictionary(grouping: lineItems, by: \.serviceCode)
        return grouped.map { code, items in
            ServiceSummary(
                serviceCode: code,
                serviceLabel: items.first?.serviceLabel ?? "Service \(code)",
                voté: items.reduce(0) { $0 + $1.voté },
                engagé: items.reduce(0) { $0 + $1.engagé },
                disponible: items.reduce(0) { $0 + $1.disponible }
            )
        }.sorted { $0.serviceCode < $1.serviceCode }
    }

    func nomenclature(forService serviceCode: Int) -> [NomenclatureSummary] {
        groupByNomenclature(lineItems.filter { $0.serviceCode == serviceCode })
    }

    var consolidatedNomenclature: [NomenclatureSummary] {
        groupByNomenclature(lineItems)
    }

    var demandeurs: [String] {
        Array(Set(lineItems.compactMap(\.demandeur))).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func groupByNomenclature(_ items: [BudgetLineItem]) -> [NomenclatureSummary] {
        let grouped = Dictionary(grouping: items, by: \.articleCode)
        return grouped.map { code, group in
            NomenclatureSummary(
                articleCode: code,
                articleLabel: group.first?.articleLabel ?? code,
                section: group.first?.section ?? .autre,
                voté: group.reduce(0) { $0 + $1.voté },
                engagé: group.reduce(0) { $0 + $1.engagé },
                disponible: group.reduce(0) { $0 + $1.disponible }
            )
        }.sorted { $0.articleCode.localizedStandardCompare($1.articleCode) == .orderedAscending }
    }

    func importFile(from url: URL) async {
        isImporting = true
        errorMessage = nil
        defer { isImporting = false }

        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        do {
            let items = try await Task.detached(priority: .userInitiated) {
                try ExcelImportService.importWorkbook(at: url)
            }.value

            try BookmarkStore.save(url: url)

            lineItems = items
            lastImportDate = Date()
            sourceFileName = url.lastPathComponent
            saveSnapshot()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshFromSavedBookmark() async {
        guard let url = BookmarkStore.resolve() else {
            errorMessage = "Aucun fichier enregistré. Importe à nouveau ton classeur."
            return
        }
        await importFile(from: url)
    }

    // MARK: - Local snapshot persistence

    private struct Snapshot: Codable {
        let lineItems: [BudgetLineItem]
        let lastImportDate: Date
        let sourceFileName: String
    }

    private func saveSnapshot() {
        guard let sourceFileName, let lastImportDate else { return }
        let snapshot = Snapshot(lineItems: lineItems, lastImportDate: lastImportDate, sourceFileName: sourceFileName)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: snapshotURL, options: .atomic)
    }

    private func loadSnapshot() {
        guard let data = try? Data(contentsOf: snapshotURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        lineItems = snapshot.lineItems
        lastImportDate = snapshot.lastImportDate
        sourceFileName = snapshot.sourceFileName
    }
}
