import SwiftUI

struct TicketListView: View {
    @StateObject private var viewModel: TicketListViewModel
    private let repository: TicketsRepository

    init(repository: TicketsRepository) {
        self.repository = repository
        _viewModel = StateObject(wrappedValue: TicketListViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.tickets.isEmpty {
                    ProgressView("Chargement des interventions…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredTickets.isEmpty {
                    ContentUnavailableFallback(
                        title: "Aucune intervention",
                        message: viewModel.errorMessage ?? "Aucun ticket ne vous est actuellement assigné."
                    )
                } else {
                    List(viewModel.filteredTickets) { ticket in
                        NavigationLink(value: ticket.id) {
                            TicketRowView(ticket: ticket)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .safeAreaInset(edge: .top) {
                if viewModel.isReadOnly {
                    ReadOnlyBanner(lastSyncedAt: viewModel.lastSyncedAt)
                }
            }
            .navigationTitle("Mes interventions")
            .navigationDestination(for: Int.self) { ticketId in
                TicketDetailView(repository: repository, ticketId: ticketId)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Statut", selection: $viewModel.statusFilter) {
                            Text("Tous").tag(TicketStatus?.none)
                            ForEach(TicketStatus.allCases) { status in
                                Text(status.label).tag(TicketStatus?.some(status))
                            }
                        }
                        Toggle("Inclure les tickets clos", isOn: $viewModel.includeClosed)
                            .onChange(of: viewModel.includeClosed) { _, _ in
                                Task { await viewModel.load() }
                            }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
            .alert(
                "Erreur",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil && !viewModel.tickets.isEmpty },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

private struct ReadOnlyBanner: View {
    let lastSyncedAt: Date?

    var body: some View {
        HStack {
            Image(systemName: "doc.text.magnifyingglass")
            VStack(alignment: .leading, spacing: 2) {
                Text("Mode fichier partagé — lecture seule")
                    .font(.caption).fontWeight(.semibold)
                if let lastSyncedAt {
                    Text("Dernière synchro : \(lastSyncedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(8)
        .background(Color.yellow.opacity(0.15))
    }
}

private struct ContentUnavailableFallback: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
