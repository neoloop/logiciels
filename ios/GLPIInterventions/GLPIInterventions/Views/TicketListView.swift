import SwiftUI

struct TicketListView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var viewModel: TicketListViewModel

    init(client: GLPIAPIClient, currentUserId: Int) {
        _viewModel = StateObject(wrappedValue: TicketListViewModel(client: client, currentUserId: currentUserId))
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
            .navigationTitle("Mes interventions")
            .navigationDestination(for: Int.self) { ticketId in
                TicketDetailView(client: auth.client!, ticketId: ticketId)
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
