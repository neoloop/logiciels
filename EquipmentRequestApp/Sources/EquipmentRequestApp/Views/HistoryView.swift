import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var config: AppConfig
    @EnvironmentObject private var authService: GraphAuthService
    private let excelService = GraphExcelService()

    @State private var rows: [[String]] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Ordre des colonnes tel qu'écrit par EquipmentRequest.excelRow.
    private let columnLabels = ["Date", "Demandeur", "Email demandeur", "Bénéficiaire", "Email bénéficiaire", "Matériel", "Justification", "Statut"]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Chargement…")
                } else if let errorMessage {
                    ContentUnavailableView("Impossible de charger l'historique", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else if rows.isEmpty {
                    ContentUnavailableView("Aucune demande", systemImage: "tray")
                } else {
                    List(Array(rows.enumerated()), id: \.offset) { _, row in
                        RowSummaryView(row: row, columnLabels: columnLabels)
                    }
                }
            }
            .navigationTitle("Historique")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let token = try await authService.acquireToken(scopes: config.graphScopes)
            rows = try await excelService.fetchRows(accessToken: token, config: config)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct RowSummaryView: View {
    let row: [String]
    let columnLabels: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(value(at: 5)) // Matériel
                    .font(.headline)
                Spacer()
                Text(value(at: 0)) // Date
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("Pour \(value(at: 3)) — demandé par \(value(at: 1))")
                .font(.subheadline)
            if row.count > 6, !value(at: 6).isEmpty {
                Text(value(at: 6))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private func value(at index: Int) -> String {
        guard index < row.count else { return "" }
        return row[index]
    }
}

#Preview {
    HistoryView()
        .environmentObject(AppConfig.shared)
        .environmentObject(GraphAuthService.shared)
}
