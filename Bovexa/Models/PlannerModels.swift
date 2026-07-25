import Foundation

/// AI-planner gespreks- en antwoordvormen — 1:1 geport uit
/// ~/Desktop/agenda-app/src/lib/aiPlanner.ts (ChatTurn/PlanResponse/ProposedAppointment).
/// Strikte validatie (valkuil B): een onbekende categorie of verkeerd type in het
/// JSON-antwoord faalt het decoderen in plaats van stilletjes iets te verzinnen.

enum ChatRole: String, Codable, Equatable {
    case user
    case assistant
}

struct ChatTurn: Codable, Equatable {
    let role: ChatRole
    let content: String
}

enum PlanStatus: String, Decodable, Equatable {
    case needsClarification = "needs_clarification"
    case ready
}

struct ProposedAppointment: Codable, Equatable {
    let title: String
    let date: String // YYYY-MM-DD (lokale Amsterdamse datum)
    let start: String // HH:MM
    let end: String // HH:MM
    let category: BovexaTheme.Category
    let location: String?
    let recurrence: String?
    let klantNaam: String?
    let klantTelefoon: String?

    /// Valkuil B: alleen deze vier — "afwezig" bestaat wel als `BovexaTheme.Category`
    /// (voor eigen afwezig-records) maar is geen geldig AI-voorstel.
    private static let allowedCategories: Set<String> = ["focus", "work", "social", "body"]

    private enum CodingKeys: String, CodingKey {
        case title, date, start, end, category, location, recurrence
        case klantNaam = "klant_naam"
        case klantTelefoon = "klant_telefoon"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        date = try c.decode(String.self, forKey: .date)
        start = try c.decode(String.self, forKey: .start)
        end = try c.decode(String.self, forKey: .end)

        let rawCategory = try c.decode(String.self, forKey: .category)
        guard Self.allowedCategories.contains(rawCategory), let category = BovexaTheme.Category(rawValue: rawCategory) else {
            throw DecodingError.dataCorruptedError(forKey: .category, in: c, debugDescription: "Onbekende categorie: \(rawCategory)")
        }
        self.category = category

        location = try c.decodeIfPresent(String.self, forKey: .location)
        recurrence = try c.decodeIfPresent(String.self, forKey: .recurrence)
        klantNaam = try c.decodeIfPresent(String.self, forKey: .klantNaam)
        klantTelefoon = try c.decodeIfPresent(String.self, forKey: .klantTelefoon)
    }

    init(
        title: String, date: String, start: String, end: String, category: BovexaTheme.Category,
        location: String? = nil, recurrence: String? = nil, klantNaam: String? = nil, klantTelefoon: String? = nil
    ) {
        self.title = title
        self.date = date
        self.start = start
        self.end = end
        self.category = category
        self.location = location
        self.recurrence = recurrence
        self.klantNaam = klantNaam
        self.klantTelefoon = klantTelefoon
    }
}

struct PlanResponse: Decodable, Equatable {
    let status: PlanStatus
    let message: String
    let question: String?
    let options: [String]
    let appointments: [ProposedAppointment]
}
