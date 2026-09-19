import SwiftUI

struct TicketRowView: View {
    let ticket: TicketSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(ticket.title)
                .font(.headline)
                .lineLimit(2)

            HStack {
                StatusBadge(status: ticket.status)
                if let priority = ticket.priority {
                    Text(priority.label)
                        .font(.caption)
                        .foregroundColor(priority.color)
                }
                Spacer()
                if let dateMod = ticket.dateMod {
                    Text(dateMod, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
