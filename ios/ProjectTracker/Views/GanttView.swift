import SwiftUI

struct GanttView: View {
    @EnvironmentObject var store: ProjectStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var year: Int = Calendar.current.component(.year, from: .now)

    private var palette: GanttPalette { GanttPalette(colorScheme: colorScheme) }

    private var availableYears: [Int] {
        let years = store.projects.flatMap {
            [Calendar.current.component(.year, from: $0.startDate), Calendar.current.component(.year, from: $0.endDate)]
        }
        let currentYear = Calendar.current.component(.year, from: .now)
        return Set(years + [currentYear]).sorted()
    }

    private var yearProjects: [Project] {
        store.projects.filter { project in
            let calendar = Calendar.current
            return calendar.component(.year, from: project.startDate) <= year
                && calendar.component(.year, from: project.endDate) >= year
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Année", selection: $year) {
                ForEach(availableYears, id: \.self) { Text(String($0)).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding()

            legend

            if yearProjects.isEmpty {
                ContentUnavailableView("Aucun projet en \(String(year))", systemImage: "chart.bar.xaxis")
            } else {
                ScrollView {
                    GanttChart(projects: yearProjects, tasks: store.tasks, year: year, palette: palette)
                        .padding()
                }
            }
        }
        .navigationTitle("Diagramme annuel")
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: palette.progress, label: "En cours")
            legendItem(color: palette.done, label: "Terminé")
            legendItem(color: palette.track, label: "Durée totale")
        }
        .font(.caption)
        .foregroundStyle(palette.textSecondary)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Capsule().fill(color).frame(width: 14, height: 8)
            Text(label)
        }
    }
}

struct GanttPalette {
    let colorScheme: ColorScheme
    var textPrimary: Color { colorScheme == .dark ? Color(hex: "ffffff") : Color(hex: "0b0b0b") }
    var textSecondary: Color { colorScheme == .dark ? Color(hex: "c3c2b7") : Color(hex: "52514e") }
    var gridline: Color { colorScheme == .dark ? Color(hex: "2c2c2a") : Color(hex: "e1e0d9") }
    var baseline: Color { colorScheme == .dark ? Color(hex: "383835") : Color(hex: "c3c2b7") }
    var track: Color { gridline }
    var progress: Color { colorScheme == .dark ? Color(hex: "3987e5") : Color(hex: "2a78d6") }
    var done: Color { Color(hex: "0ca30c") }
}

private extension Color {
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }
}

private struct GanttChart: View {
    let projects: [Project]
    let tasks: [ProjectTask]
    let year: Int
    let palette: GanttPalette

    private let rowHeight: CGFloat = 36
    private let labelWidth: CGFloat = 110
    private let monthNames = ["Jan", "Fév", "Mar", "Avr", "Mai", "Juin", "Juil", "Août", "Sep", "Oct", "Nov", "Déc"]

    private var yearStart: Date { DateComponents(calendar: .current, year: year, month: 1, day: 1).date! }
    private var yearEnd: Date { DateComponents(calendar: .current, year: year, month: 12, day: 31).date! }
    private var totalDays: Double { yearEnd.timeIntervalSince(yearStart) / 86400 + 1 }

    var body: some View {
        GeometryReader { geo in
            let chartWidth = max(geo.size.width - labelWidth, 0)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Color.clear.frame(width: labelWidth)
                    ForEach(0..<12, id: \.self) { month in
                        Text(monthNames[month])
                            .font(.caption2)
                            .foregroundStyle(palette.textSecondary)
                            .frame(width: chartWidth / 12, alignment: .leading)
                    }
                }
                .frame(height: 20)

                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        ForEach(0..<12, id: \.self) { _ in
                            Rectangle()
                                .fill(palette.gridline)
                                .frame(width: 1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.leading, labelWidth)
                    .frame(height: CGFloat(projects.count) * rowHeight)

                    VStack(spacing: 0) {
                        ForEach(projects) { project in
                            GanttRow(
                                project: project,
                                progress: progress(for: project),
                                yearStart: yearStart,
                                totalDays: totalDays,
                                chartWidth: chartWidth,
                                labelWidth: labelWidth,
                                rowHeight: rowHeight,
                                palette: palette
                            )
                        }
                    }

                    if let todayOffset = todayOffset(chartWidth: chartWidth) {
                        Rectangle()
                            .fill(palette.baseline)
                            .frame(width: 1.5, height: CGFloat(projects.count) * rowHeight)
                            .offset(x: labelWidth + todayOffset)
                    }
                }
            }
        }
        .frame(height: CGFloat(projects.count) * rowHeight + 24)
    }

    private func progress(for project: Project) -> Double {
        let projectTasks = tasks.filter { $0.projectId == project.id }
        guard !projectTasks.isEmpty else { return 0 }
        return Double(projectTasks.filter { $0.status == .done }.count) / Double(projectTasks.count)
    }

    private func todayOffset(chartWidth: CGFloat) -> CGFloat? {
        guard Calendar.current.component(.year, from: .now) == year else { return nil }
        let offsetDays = Date.now.timeIntervalSince(yearStart) / 86400
        return chartWidth * CGFloat(offsetDays / totalDays)
    }
}

private struct GanttRow: View {
    let project: Project
    let progress: Double
    let yearStart: Date
    let totalDays: Double
    let chartWidth: CGFloat
    let labelWidth: CGFloat
    let rowHeight: CGFloat
    let palette: GanttPalette

    var body: some View {
        HStack(spacing: 0) {
            Text(project.name)
                .font(.caption)
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
                .frame(width: labelWidth, alignment: .leading)
                .padding(.trailing, 4)

            ZStack(alignment: .leading) {
                let start = max(0, project.startDate.timeIntervalSince(yearStart) / 86400)
                let end = min(totalDays, project.endDate.timeIntervalSince(yearStart) / 86400 + 1)
                let barX = chartWidth * CGFloat(start / totalDays)
                let barWidth = max(chartWidth * CGFloat((end - start) / totalDays), 3)

                Capsule()
                    .fill(palette.track)
                    .frame(width: barWidth, height: 10)
                    .offset(x: barX)

                Capsule()
                    .fill(progress >= 1 ? palette.done : palette.progress)
                    .frame(width: max(barWidth * CGFloat(progress), progress > 0 ? 3 : 0), height: 10)
                    .offset(x: barX)
            }
            .frame(width: chartWidth, height: rowHeight, alignment: .leading)
        }
        .frame(height: rowHeight)
    }
}
