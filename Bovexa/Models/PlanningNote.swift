import Foundation

/// Persoonlijke dagtaak — blijft lokaal op het toestel (UserDefaults), gaat nooit naar
/// de server (valkuil A). Zelfde velden als PlanningNote in
/// ~/Desktop/agenda-app/src/lib/planningNotes.ts, maar eigen opslag: geen migratie of
/// import tussen de RN- en Swift-app.
struct PlanningNote: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let body: String
    let done: Bool
    let createdAt: Date
    let updatedAt: Date
    let archived: Bool

    init(id: String, title: String, body: String, done: Bool, createdAt: Date, updatedAt: Date, archived: Bool) {
        self.id = id
        self.title = title
        self.body = body
        self.done = done
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archived = archived
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, body, done, createdAt, updatedAt, archived
    }

    /// Vergevingsgezind bij oude data zonder `archived` — leest dan als false.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        body = try values.decode(String.self, forKey: .body)
        done = try values.decode(Bool.self, forKey: .done)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        updatedAt = try values.decode(Date.self, forKey: .updatedAt)
        archived = try values.decodeIfPresent(Bool.self, forKey: .archived) ?? false
    }

    func withDone(_ done: Bool, updatedAt: Date = Date()) -> PlanningNote {
        PlanningNote(id: id, title: title, body: body, done: done, createdAt: createdAt, updatedAt: updatedAt, archived: archived)
    }

    func withArchived(_ archived: Bool, updatedAt: Date = Date()) -> PlanningNote {
        PlanningNote(id: id, title: title, body: body, done: done, createdAt: createdAt, updatedAt: updatedAt, archived: archived)
    }
}
