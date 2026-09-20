import SwiftUI

/// Écran principal de l'app : les demandes soumises par les employés (via la
/// page web ou tout autre moyen alimentant le fichier JSON) et pas encore traitées.
struct PendingRequestsView: View {
    @EnvironmentObject private var config: AppConfig
    @EnvironmentObject private var authService: GraphAuthService
    private let jsonService = GraphJsonService()

    @State private var document = RequestsDocument()
    @State private var etag: String?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var pendingRequests: [JsonEquipmentRequest] {
        document.requests.filter { $0.requestStatus == .pending }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Chargement…")
                } else if let errorMessage {
                    ContentUnavailableView("Impossible de charger les demandes", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else if pendingRequests.isEmpty {
                    ContentUnavailableView("Aucune demande en attente", systemImage: "checkmark.circle")
                } else {
                    List(pendingRequests) { item in
                        NavigationLink {
                            PendingRequestDetailView(request: item, document: document, etag: etag, onHandled: {
                                Task { await load() }
                            })
                        } label: {
                            PendingRowLabel(item: item)
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
            let result = try await jsonService.fetch(accessToken: token, config: config)
            document = result.document
            etag = result.etag
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct PendingRowLabel: View {
    let item: JsonEquipmentRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.equipment.isEmpty ? "Matériel non précisé" : item.equipment)
                    .font(.headline)
                Spacer()
                if !item.date.isEmpty {
                    Text(item.date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Text("Pour \(item.beneficiaryName) — demandé par \(item.requesterName)")
                .font(.subheadline)
            if !item.justification.isEmpty {
                Text(item.justification)
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
