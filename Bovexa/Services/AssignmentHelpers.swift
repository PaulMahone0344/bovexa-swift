import Foundation

/// Toewijzings-logica (valkuil B) — geport uit ~/Desktop/agenda-app/src/lib/assignments.ts.
/// assignee_status staat als json-map op het event: userId → "pending" | "accepted" | "declined".
enum AssignmentHelpers {
    /// Nieuwe assignee_status-map voor een nieuwe/gewijzigde toewijzing: de eigenaar
    /// die zichzelf toewijst hoeft niets te accepteren, de rest komt op "pending" tenzij
    /// er al een antwoord stond. Wie eraf gehaald is verdwijnt uit de map.
    static func nextStatusMap(assignees: [String], ownerId: String, previous: [String: String] = [:]) -> [String: String] {
        var next: [String: String] = [:]
        for id in assignees {
            next[id] = id == ownerId ? "accepted" : (previous[id] ?? "pending")
        }
        return next
    }

    /// Status van één persoon. nil = niet toegewezen. Ontbrekende sleutel = "pending".
    static func assignmentStatus(assignees: [String], statusMap: [String: String], userId: String) -> String? {
        guard assignees.contains(userId) else { return nil }
        return statusMap[userId] ?? "pending"
    }

    /// Aantal toewijzingen dat op jouw akkoord wacht (m6, Profiel-teller/-stip).
    static func pendingCount(_ events: [AgendaEvent], userId: String) -> Int {
        events.filter { assignmentStatus(assignees: $0.assignee, statusMap: $0.assigneeStatus, userId: userId) == "pending" }.count
    }
}
