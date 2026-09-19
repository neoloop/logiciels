import SwiftUI

struct TicketDetailView: View {
    @StateObject private var viewModel: TicketDetailViewModel

    init(client: GLPIAPIClient, ticketId: Int) {
        _viewModel = StateObject(wrappedValue: TicketDetailViewModel(ticketId: ticketId, client: client))
    }

    var body: some View {
        Group {
            if let ticket = viewModel.ticket {
                Form {
                    Section {
                        Text(ticket.name)
                            .font(.title3)
                            .fontWeight(.semibold)
                        HStack {
                            StatusBadge(status: ticket.status)
                            if let priority = ticket.priority {
                                Text(priority.label)
                                    .font(.caption)
                                    .foregroundColor(priority.color)
                            }
                        }
                        if let date = ticket.date {
                            Label(date.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Description") {
                        Text(HTMLText.plainText(from: ticket.content))
                            .font(.body)
                    }

                    Section("Changer le statut") {
                        Picker("Statut", selection: Binding(
                            get: { ticket.status },
                            set: { newStatus in Task { await viewModel.updateStatus(to: newStatus) } }
                        )) {
                            ForEach(TicketStatus.editableCases) { status in
                                Text(status.label).tag(status)
                            }
                            if !TicketStatus.editableCases.contains(ticket.status) {
                                Text(ticket.status.label).tag(ticket.status)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(viewModel.isUpdating)
                    }

                    Section("Suivis (\(viewModel.followups.count))") {
                        if viewModel.followups.isEmpty {
                            Text("Aucun suivi pour le moment.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(viewModel.followups) { followup in
                            VStack(alignment: .leading, spacing: 4) {
                                if let date = followup.date {
                                    Text(date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Text(HTMLText.plainText(from: followup.content))
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 2)
                        }

                        HStack(alignment: .bottom) {
                            TextField("Ajouter un suivi…", text: $viewModel.newFollowupText, axis: .vertical)
                                .lineLimit(1...4)
                            Button {
                                Task { await viewModel.submitFollowup() }
                            } label: {
                                Image(systemName: "paperplane.fill")
                            }
                            .disabled(viewModel.newFollowupText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isUpdating)
                        }
                    }
                }
            } else if viewModel.isLoading {
                ProgressView("Chargement…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text(viewModel.errorMessage ?? "Ticket introuvable.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Ticket #\(viewModel.ticketId)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}
