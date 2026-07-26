import Foundation

/// Team-dagtaken-datalaag: agenda_tasks. Org-scoping gebeurt server-side via de
/// PB-rules — hier bewust geen extra org-filter (zelfde principe als EventRepository
/// en de comment bovenaan src/lib/tasks.ts in de RN-app).
final class TaskRepository {
    private let client: PBClient
    private static let collection = "agenda_tasks"

    init(client: PBClient = PBClient()) {
        self.client = client
    }

    func fetchTasks(token: String) async throws -> [AgendaTask] {
        try await client.getFullList(AgendaTask.self, collection: Self.collection, filter: "", sort: "-created", expand: "owner", token: token)
    }

    /// Payload zoals createTask in tasks.ts: zonder expliciete keuze valt visibility
    /// terug op 'company' bij een org, anders 'private'; viewers alleen gevuld bij
    /// visibility 'people'.
    func createTask(
        owner: String, org: String?, title: String, notes: String = "",
        visibility: TaskVisibility? = nil, viewers: [String] = [], token: String
    ) async throws -> AgendaTask {
        let orgValue = org ?? ""
        let resolvedVisibility = visibility ?? (orgValue.isEmpty ? .private : .company)
        let body: [String: Any] = [
            "owner": owner,
            "org": orgValue,
            "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
            "notes": notes.trimmingCharacters(in: .whitespacesAndNewlines),
            "status": TaskStatus.open.rawValue,
            "visibility": resolvedVisibility.rawValue,
            "viewers": resolvedVisibility == .people ? viewers : [],
        ]
        return try await client.createRecord(AgendaTask.self, collection: Self.collection, body: body, token: token)
    }

    /// completedAt: het tijdstip van afvinken (m8) — nil wist het veld weer bij uitvinken.
    @discardableResult
    func setStatus(id: String, status: TaskStatus, completedAt: Date? = nil, token: String) async throws -> AgendaTask {
        var body: [String: Any] = ["status": status.rawValue]
        body["completed_at"] = completedAt.map(PBDate.format) ?? NSNull()
        return try await client.updateRecord(AgendaTask.self, collection: Self.collection, id: id, body: body, token: token)
    }

    func deleteTask(id: String, token: String) async throws {
        try await client.deleteRecord(collection: Self.collection, id: id, token: token)
    }
}
