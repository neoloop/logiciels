import SwiftUI

/// Écran principal de l'app : les demandes soumises par les employés via le
/// formulaire externe (qui alimente le tableau Excel) et pas encore traitées.
struct PendingRequestsView: View {
    @EnvironmentObject private var config: AppConfig
    @EnvironmentObject private var authService: GraphAuthService
    private let excelService = GraphExcelService()

    @State private var columnMap: ColumnMap?
    @State private var rows: [ExcelEquipmentRequestRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var pendingRows: [ExcelEquipmentRequestRow] {
        rows.filter { $0.status == .pending }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Chargement…")
                } else if let errorMessage {
                    ContentUnavailableView("Impossible de charger les demandes", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else if pendingRows.isEmpty {
                    ContentUnavailableView("Aucune demande en attente", systemImage: "checkmark.circle")
                } else if let columnMap {
                    List(pendingRows) { row in
                        NavigationLink {
                            PendingRequestDetailView(row: row, columnMap: columnMap, onHandled: {
                                Task { await load() }
                            })
                        } label: {
                            PendingRowLabel(row: row)
                        }
                    }
                }
            }
            .navigationTitle("À valider")
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
            let result = try await excelService.fetchRequests(accessToken: token, config: config)
            columnMap = result.columnMap
            rows = result.rows
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct PendingRowLabel: View {
    let row: ExcelEquipmentRequestRow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(row.equipmentLabel.isEmpty ? "Matériel non précisé" : row.equipmentLabel)
                    .font(.headline)
                Spacer()
                if !row.date.isEmpty {
                    Text(row.date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Text("Pour \(row.beneficiaryName) — demandé par \(row.requesterName)")
                .font(.subheadline)
            if !row.justification.isEmpty {
                Text(row.justification)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PendingRequestsView()
        .environmentObject(AppConfig.shared)
        .environmentObject(GraphAuthService.shared)
}
