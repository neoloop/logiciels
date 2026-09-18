import Foundation

/// Central app state: holds the last imported transactions/budget, the selected month for
/// analysis, and a local JSON snapshot so the dashboard has data immediately on relaunch
/// without re-reading the (possibly remote, OneDrive-backed) source file.
@MainActor
final class BudgetDataStore: ObservableObject {
    @Published private(set) var transactions: [Transaction] = []
    @Published private(set) var budgetLines: [BudgetLine] = []
    @Published var selectedMonth: Date = Calendar.current.startOfMonth(for: Date())
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

    var availableMonths: [Date] {
        let calendar = Calendar.current
        let months = Set(transactions.map { calendar.startOfMonth(for: $0.date) })
        return months.sorted(by: >)
    }

    var categorySummaries: [CategorySummary] {
        let calendar = Calendar.current
        let monthTransactions = transactions.filter {
            calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }

        var actualsByCategory: [String: Double] = [:]
        for transaction in monthTransactions {
            actualsByCategory[transaction.category, default: 0] += abs(transaction.amount)
        }

        var summaries: [CategorySummary] = []
        var handledCategories = Set<String>()

        for line in budgetLines {
            let actual = actualsByCategory[line.category] ?? 0
            summaries.append(CategorySummary(category: line.category, budget: line.monthlyAmount, actual: actual))
            handledCategories.insert(line.category)
        }

        for (category, actual) in actualsByCategory where !handledCategories.contains(category) {
            summaries.append(CategorySummary(category: category, budget: nil, actual: actual))
        }

        return summaries.sorted { $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending }
    }

    var totalBudget: Double {
        budgetLines.reduce(0) { $0 + $1.monthlyAmount }
    }

    var totalActual: Double {
        categorySummaries.reduce(0) { $0 + $1.actual }
    }

    func importFile(from url: URL) async {
        isImporting = true
        errorMessage = nil
        defer { isImporting = false }

        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try ExcelImportService.importWorkbook(at: url)
            }.value

            try BookmarkStore.save(url: url)

            transactions = result.transactions
            budgetLines = result.budgetLines
            lastImportDate = Date()
            sourceFileName = url.lastPathComponent
            if let latestMonth = availableMonths.first {
                selectedMonth = latestMonth
            }
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
        let transactions: [Transaction]
        let budgetLines: [BudgetLine]
        let lastImportDate: Date
        let sourceFileName: String
    }

    private func saveSnapshot() {
        guard let sourceFileName, let lastImportDate else { return }
        let snapshot = Snapshot(
            transactions: transactions,
            budgetLines: budgetLines,
            lastImportDate: lastImportDate,
            sourceFileName: sourceFileName
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: snapshotURL, options: .atomic)
    }

    private func loadSnapshot() {
        guard let data = try? Data(contentsOf: snapshotURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        transactions = snapshot.transactions
        budgetLines = snapshot.budgetLines
        lastImportDate = snapshot.lastImportDate
        sourceFileName = snapshot.sourceFileName
        if let latestMonth = availableMonths.first {
            selectedMonth = latestMonth
        }
    }
}
