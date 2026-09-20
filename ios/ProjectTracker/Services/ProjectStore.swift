import Foundation

/// Local cache of Project/ProjectTask, backed by the shared Excel workbook.
/// Excel table rows are the source of truth — every mutation writes through to Graph,
/// then reloads the affected table so the row-index cache used for later updates/deletes
/// stays correct.
@MainActor
final class ProjectStore: ObservableObject {
    @Published var projects: [Project] = []
    @Published var tasks: [ProjectTask] = []
    @Published var isSyncing = false
    @Published var syncError: String?

    private let service = GraphExcelService()
    private let auth = AuthManager.shared

    private var projectRowIndex: [String: Int] = [:]
    private var taskRowIndex: [String: Int] = [:]

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    /// Excel's day-zero, used to decode dates that Excel auto-converted to a numeric serial
    /// despite the column being written as a "yyyy-MM-dd" string (format the columns as Text
    /// in the workbook to avoid this — see docs/SETUP.md).
    private static let excelEpoch = Date(timeIntervalSince1970: -2_209_161_600)

    func tasks(for projectId: String) -> [ProjectTask] {
        tasks.filter { $0.projectId == projectId }.sorted { $0.order < $1.order }
    }

    func refresh() async {
        isSyncing = true
        syncError = nil
        defer { isSyncing = false }
        do {
            let token = try await auth.acquireTokenSilently()
            async let projectRowsTask = service.rows(table: "Projects", token: token)
            async let taskRowsTask = service.rows(table: "Tasks", token: token)
            let (projectRows, taskRows) = try await (projectRowsTask, taskRowsTask)

            var loadedProjects: [Project] = []
            var newProjectIndex: [String: Int] = [:]
            for (index, row) in projectRows.enumerated() {
                guard row.count >= 6,
                      let start = Self.parseDate(row[2]),
                      let end = Self.parseDate(row[3])
                else { continue }
                loadedProjects.append(Project(id: row[0], name: row[1], startDate: start, endDate: end, notes: row[5]))
                newProjectIndex[row[0]] = index
            }

            var loadedTasks: [ProjectTask] = []
            var newTaskIndex: [String: Int] = [:]
            for (index, row) in taskRows.enumerated() {
                guard row.count >= 5,
                      let status = TaskStatus(rawValue: row[3]),
                      let order = Int(row[4])
                else { continue }
                loadedTasks.append(ProjectTask(id: row[0], projectId: row[1], name: row[2], status: status, order: order))
                newTaskIndex[row[0]] = index
            }

            projects = loadedProjects.sorted { $0.startDate < $1.startDate }
            tasks = loadedTasks
            projectRowIndex = newProjectIndex
            taskRowIndex = newTaskIndex
        } catch {
            syncError = error.localizedDescription
        }
    }

    func saveProject(_ project: Project) async {
        do {
            let token = try await auth.acquireTokenSilently()
            let values = [
                project.id, project.name,
                Self.format(project.startDate), Self.format(project.endDate),
                String(project.durationInDays), project.notes,
            ]
            if let index = projectRowIndex[project.id] {
                try await service.updateRow(table: "Projects", index: index, values: values, token: token)
            } else {
                try await service.addRow(table: "Projects", values: values, token: token)
            }
            await refresh()
        } catch {
            syncError = error.localizedDescription
        }
    }

    func deleteProject(_ project: Project) async {
        do {
            let token = try await auth.acquireTokenSilently()
            // Delete highest row index first: removing a row shifts every following index down,
            // so deleting low-to-high would target the wrong rows partway through.
            let relatedTaskIndices = tasks(for: project.id)
                .compactMap { taskRowIndex[$0.id] }
                .sorted(by: >)
            for index in relatedTaskIndices {
                try await service.deleteRow(table: "Tasks", index: index, token: token)
            }
            if let index = projectRowIndex[project.id] {
                try await service.deleteRow(table: "Projects", index: index, token: token)
            }
            await refresh()
        } catch {
            syncError = error.localizedDescription
        }
    }

    func saveTask(_ task: ProjectTask) async {
        do {
            let token = try await auth.acquireTokenSilently()
            let values = [task.id, task.projectId, task.name, task.status.rawValue, String(task.order)]
            if let index = taskRowIndex[task.id] {
                try await service.updateRow(table: "Tasks", index: index, values: values, token: token)
            } else {
                try await service.addRow(table: "Tasks", values: values, token: token)
            }
            await refresh()
        } catch {
            syncError = error.localizedDescription
        }
    }

    func deleteTask(_ task: ProjectTask) async {
        do {
            let token = try await auth.acquireTokenSilently()
            if let index = taskRowIndex[task.id] {
                try await service.deleteRow(table: "Tasks", index: index, token: token)
            }
            await refresh()
        } catch {
            syncError = error.localizedDescription
        }
    }

    private static func parseDate(_ raw: String) -> Date? {
        if let date = dateFormatter.date(from: raw) { return date }
        if let serial = Double(raw) { return excelEpoch.addingTimeInterval(serial * 86400) }
        return nil
    }

    private static func format(_ date: Date) -> String { dateFormatter.string(from: date) }
}
