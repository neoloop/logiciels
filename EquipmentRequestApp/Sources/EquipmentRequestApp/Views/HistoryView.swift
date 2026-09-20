import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var config: AppConfig
    @EnvironmentObject private var authService: GraphAuthService
    private let excelService = GraphExcelService()

    @State private var rows: [ExcelEquipmentRequestRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

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
                    List(rows) { row in
                        RowSummaryView(row: row)
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
            rows = try await excelService.fetchRequests(accessToken: token, config: config).rows
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct RowSummaryView: View {
    let row: ExcelEquipmentRequestRow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(row.equipmentLabel.isEmpty ? "Matériel non précisé" : row.equipmentLabel)
                    .font(.headline)
                Spacer()
                StatusBadge(status: row.status)
            }
            Text("Pour \(row.beneficiaryName) — demandé par \(row.requesterName)")
                .font(.subheadline)
            if !row.date.isEmpty {
                Text(row.date)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct StatusBadge: View {
    let status: RequestStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch status {
        case .pending: return .orange
        case .inProgress: return .blue
        case .processed: return .green
        case .rejected: return .red
        }
    }
}

#Preview {
    HistoryView()
        .environmentObject(AppConfig.shared)
        .environmentObject(GraphAuthService.shared)
}
