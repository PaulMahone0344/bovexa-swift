import Foundation

/// Status op agenda_tasks. 'bezig' bestaat in het model maar wordt in de
/// Dagtaken-tab niet gebruikt (alleen open/klaar via het vinkje).
enum TaskStatus: String, Codable, Equatable {
    case open, bezig, klaar
}

/// Zichtbaarheid op agenda_tasks. Alleen private/company zijn kiesbaar vanuit de
/// Dagtaken-composer; 'people' bestaat in het model (RN kent hem ook op andere
/// schermen) maar wordt hier nooit geschreven.
enum TaskVisibility: String, Codable, Equatable {
    case `private`
    case company
    case people
}

/// agenda_tasks — team-dagtaken. Naam "AgendaTask" i.p.v. "Task" om botsing met
/// Swift's eigen `Task` (structured concurrency) te vermijden.
struct AgendaTask: Decodable, Identifiable, Equatable {
    let id: String
    let owner: String
    let org: String?
    let title: String
    let notes: String?
    let status: TaskStatus
    let visibility: TaskVisibility?
    let viewers: [String]
    let created: Date
    let updated: Date
    let expand: Expand?
    /// Tijdstip van afvinken (m8, klantverzoek 26 juli). Nil zolang open, of bij
    /// taken die al klaar waren voordat dit veld bestond.
    let completedAt: Date?
    /// Wie de taak heeft afgevinkt (relatie naar agenda_users, sinds 7 september).
    /// Nil zolang open, en ook bij taken die al klaar waren voordat dit veld
    /// bestond — daar valt de naam niet meer te achterhalen. Een lege relatie komt
    /// als "" binnen; die wordt hier nil, zodat de app niet op leegte hoeft te
    /// controleren.
    let completedBy: String?

    struct Expand: Decodable, Equatable {
        let owner: AgendaUser?
    }

    enum CodingKeys: String, CodingKey {
        case id, owner, org, title, notes, status, visibility, viewers, created, updated, expand
        case completedAt = "completed_at"
        case completedBy = "completed_by"
    }

    init(
        id: String, owner: String, org: String?, title: String, notes: String?,
        status: TaskStatus, visibility: TaskVisibility?, viewers: [String],
        created: Date, updated: Date, expand: Expand? = nil, completedAt: Date? = nil,
        completedBy: String? = nil
    ) {
        self.id = id
        self.owner = owner
        self.org = org
        self.title = title
        self.notes = notes
        self.status = status
        self.visibility = visibility
        self.viewers = viewers
        self.created = created
        self.updated = updated
        self.expand = expand
        self.completedAt = completedAt
        self.completedBy = completedBy
    }

    /// Defensief decoderen, zelfde stijl als AgendaEvent: onverwachte of ontbrekende
    /// velden geven een nette fallback in plaats van een crash.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        owner = try c.decode(String.self, forKey: .owner)
        org = Self.decodeOptional(c, .org)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        notes = Self.decodeOptional(c, .notes)
        status = Self.decodeOptional(c, .status) ?? .open
        visibility = Self.decodeOptional(c, .visibility)
        viewers = Self.decodeOptional(c, .viewers) ?? []
        created = Self.decodeOptional(c, .created, as: String.self).flatMap(PBDate.parse) ?? Date(timeIntervalSince1970: 0)
        updated = Self.decodeOptional(c, .updated, as: String.self).flatMap(PBDate.parse) ?? Date(timeIntervalSince1970: 0)
        expand = Self.decodeOptional(c, .expand)
        completedAt = Self.decodeOptional(c, .completedAt, as: String.self).flatMap(PBDate.parse)
        completedBy = Self.decodeOptional(c, .completedBy, as: String.self).flatMap { $0.isEmpty ? nil : $0 }
    }

    private static func decodeOptional<T: Decodable>(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys, as type: T.Type = T.self) -> T? {
        (try? c.decodeIfPresent(T.self, forKey: key)) ?? nil
    }

    /// Afvinken zet completedAt en completedBy; uitvinken wist ze allebei weer.
    func withStatus(_ status: TaskStatus, completedAt: Date? = nil, completedBy: String? = nil) -> AgendaTask {
        AgendaTask(
            id: id, owner: owner, org: org, title: title, notes: notes, status: status,
            visibility: visibility, viewers: viewers, created: created, updated: updated, expand: expand,
            completedAt: status == .klaar ? (completedAt ?? self.completedAt) : nil,
            completedBy: status == .klaar ? (completedBy ?? self.completedBy) : nil
        )
    }
}
