import SwiftUI
import SwiftData
import Charts

private struct DepthBucket: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
}

struct StatsView: View {
    @Query private var dives: [Dive]

    private var totalDurationMinutes: Int {
        dives.reduce(0) { $0 + $1.durationMinutes }
    }

    private var totalDepth: Double {
        dives.reduce(0) { $0 + $1.depth }
    }

    private var buckets: [DepthBucket] {
        let ranges: [(String, (Double) -> Bool)] = [
            ("≤ 20 m", { $0 <= 20 }),
            ("20-40 m", { $0 > 20 && $0 <= 40 }),
            ("40-60 m", { $0 > 40 && $0 <= 60 }),
            ("> 60 m", { $0 > 60 })
        ]
        return ranges.map { label, matches in
            DepthBucket(label: label, count: dives.filter { matches($0.depth) }.count)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Résumé") {
                    LabeledContent("Nombre de plongées", value: "\(dives.count)")
                    LabeledContent("Durée totale", value: DiveFormatters.duration(totalDurationMinutes))
                    LabeledContent("Profondeur cumulée", value: DiveFormatters.depth(totalDepth))
                }

                Section("Plongées par profondeur") {
                    if dives.isEmpty {
                        Text("Aucune donnée pour le moment")
                            .foregroundStyle(.secondary)
                    } else {
                        Chart(buckets) { bucket in
                            BarMark(
                                x: .value("Tranche", bucket.label),
                                y: .value("Plongées", bucket.count)
                            )
                            .annotation(position: .top) {
                                Text("\(bucket.count)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(height: 200)
                        .padding(.vertical, 8)

                        ForEach(buckets) { bucket in
                            LabeledContent(bucket.label, value: "\(bucket.count)")
                        }
                    }
                }
            }
            .navigationTitle("Statistiques")
        }
    }
}

#Preview {
    StatsView()
        .modelContainer(for: Dive.self, inMemory: true)
}
