import SwiftUI

struct DiveRowView: View {
    let dive: Dive

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(DiveFormatters.dateFormatter.string(from: dive.date))
                    .font(.headline)
                Spacer()
                if dive.status == .planned {
                    statusBadge
                } else if dive.depth > 0 {
                    Text(DiveFormatters.depth(dive.depth))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                if dive.durationMinutes > 0 {
                    Label(DiveFormatters.duration(dive.durationMinutes), systemImage: "timer")
                }
                if let locationName = dive.locationName {
                    Label(locationName, systemImage: "mappin.and.ellipse")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !dive.buddies.isEmpty {
                Text(dive.buddies.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusBadge: some View {
        Text(DiveStatus.planned.label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.15))
            .foregroundStyle(.orange)
            .clipShape(Capsule())
    }
}
