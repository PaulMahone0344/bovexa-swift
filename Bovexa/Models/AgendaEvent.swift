import Foundation

/// agenda_events — alleen velden die milestone 1 gebruikt (Vandaag/Agenda/detail).
/// Defensief decoderen (valkuil B): oude/afwijkende server-vormen mogen nooit crashen.
struct AgendaEvent: Decodable, Identifiable, Equatable {
    let id: String
    let owner: String
    let calendar: String?
    let category: BovexaTheme.Category?
    let title: String
    let start: Date
    let end: Date?
    let allDay: Bool
    let recurrence: String?
    let location: String?
    let notes: String?
    let klantNaam: String?
    let assigneeStatus: [String: String]
    var seriesId: String?
    var occurrenceDate: String?

    enum CodingKeys: String, CodingKey {
        case id, owner, calendar, category, title, start, end
        case allDay = "all_day"
        case recurrence, location, notes
        case klantNaam = "klant_naam"
        case assigneeStatus = "assignee_status"
        case seriesId = "series_id"
        case occurrenceDate = "occurrence_date"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        owner = try c.decode(String.self, forKey: .owner)
        calendar = Self.decodeOptional(c, .calendar)
        category = Self.decodeOptional(c, .category)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""

        let startRaw = (try? c.decode(String.self, forKey: .start)) ?? ""
        start = PBDate.parse(startRaw) ?? Date(timeIntervalSince1970: 0)
        end = Self.decodeOptional(c, .end, as: String.self).flatMap(PBDate.parse)

        allDay = Self.decodeOptional(c, .allDay) ?? false
        recurrence = Self.decodeOptional(c, .recurrence)
        location = Self.decodeOptional(c, .location)
        notes = Self.decodeOptional(c, .notes)
        klantNaam = Self.decodeOptional(c, .klantNaam)
        assigneeStatus = Self.decodeOptional(c, .assigneeStatus) ?? [:]
        seriesId = Self.decodeOptional(c, .seriesId)
        occurrenceDate = Self.decodeOptional(c, .occurrenceDate)
    }

    /// Ontbrekende sleutel, null, of een onverwacht type → nil in plaats van crash.
    private static func decodeOptional<T: Decodable>(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys, as type: T.Type = T.self) -> T? {
        (try? c.decodeIfPresent(T.self, forKey: key)) ?? nil
    }
}
