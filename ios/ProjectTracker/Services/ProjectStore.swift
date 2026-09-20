import Foundation

private struct StoreFile: Codable {
    var projects: [ProjectRecord] = []
    var tasks: [TaskRecord] = []
}

private struct ProjectRecord: Codable {
    var id: String
    var name: String
    var startDate: String
    var endDate: String
    var notes: String
}

private struct TaskRecord: Codable {
    var id: String
    var projectId: String
    var name: String
    var status: String
    var order: Int
}

/// Local cache of Project/ProjectTask, backed by the shared JSON file on OneDrive. Every mutation
/// updates the in-memory arrays and re-uploads the whole file — no server, no partial updates.
@MainActor
final class ProjectStore: ObservableObject {
    @Published var projects: [Project] = []
    @Published var tasks: [ProjectTask] = []
    @Published var isSyncing = false
    @Published var syncError: String?

    private let service = GraphStoreService()
    private let auth = AuthManager.shared

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    func tasks(for projectId: String) -> [ProjectTask] {
        tasks.filter { $0.projectId == projectId }.sorted { $0.order < $1.order }
    }

    func refresh() async {
        isSyncing = true
        syncError = nil
        defer { isSyncing = false }
        do {
            let token = try await auth.acquireTokenSilently()
            guard let data = try await service.download(token: token) else {
                projects = []
                tasks = []
                return
            }
            let file = try JSONDecoder().decode(StoreFile.self, from: data)
            projects = file.projects.compactMap { record in
                guard let start = Self.parseDate(record.startDate), let end = Self.parseDate(record.endDate) else { return nil }
                return Project(id: record.id, name: record.name, startDate: start, endDate: end, notes: record.notes)
            }.sorted { $0.startDate < $1.startDate }
            tasks = file.tasks.compactMap { record in
                guard let status = TaskStatus(rawValue: record.status) else { return nil }
                return ProjectTask(id: record.id, projectId: record.projectId, name: record.name, status: status, order: record.order)
            }
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func persist() async {
        do {
            let token = try await auth.acquireTokenSilently()
            let file = StoreFile(
                projects: projects.map {
                    ProjectRecord(id: $0.id, name: $0.name, startDate: Self.format($0.startDate), endDate: Self.format($0.endDate), notes: $0.notes)
                },
                tasks: tasks.map {
                    TaskRecord(id: $0.id, projectId: $0.projectId, name: $0.name, status: $0.status.rawValue, order: $0.order)
                }
            )
            let data = try JSONEncoder().encode(file)
            try await service.upload(data, token: token)
        } catch {
            syncError = error.localizedDescription
        }
    }

    func saveProject(_ project: Project) async {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        } else {
            projects.append(project)
        }
        await persist()
    }

    func deleteProject(_ project: Project) async {
        projects.removeAll { $0.id == project.id }
        tasks.removeAll { $0.projectId == project.id }
        await persist()
    }

    func saveTask(_ task: ProjectTask) async {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        } else {
            tasks.append(task)
        }
        await persist()
    }

    func deleteTask(_ task: ProjectTask) async {
        tasks.removeAll { $0.id == task.id }
        await persist()
    }

    private static func parseDate(_ raw: String) -> Date? { dateFormatter.date(from: raw) }
    private static func format(_ date: Date) -> String { dateFormatter.string(from: date) }
}
