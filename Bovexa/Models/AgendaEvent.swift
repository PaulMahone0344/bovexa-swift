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
    let seriesId: String?
    let occurrenceDate: String?

    init(
        id: String, owner: String, calendar: String?, category: BovexaTheme.Category?,
        title: String, start: Date, end: Date?, allDay: Bool, recurrence: String?,
        location: String?, notes: String?, klantNaam: String?,
        assigneeStatus: [String: String], seriesId: String?, occurrenceDate: String?
    ) {
        self.id = id
        self.owner = owner
        self.calendar = calendar
        self.category = category
        self.title = title
        self.start = start
        self.end = end
        self.allDay = allDay
        self.recurrence = recurrence
        self.location = location
        self.notes = notes
        self.klantNaam = klantNaam
        self.assigneeStatus = assigneeStatus
        self.seriesId = seriesId
        self.occurrenceDate = occurrenceDate
    }

    /// Kopie met andere id/tijd/serie — gebruikt door RecurrenceExpander om een
    /// uitgeklapte losse dag te maken zonder de rest van de afspraak te herhalen.
    func withOccurrence(id: String, start: Date, end: Date?, seriesId: String, occurrenceDate: String) -> AgendaEvent {
        AgendaEvent(
            id: id, owner: owner, calendar: calendar, category: category, title: title,
            start: start, end: end, allDay: allDay, recurrence: recurrence, location: location,
            notes: notes, klantNaam: klantNaam, assigneeStatus: assigneeStatus,
            seriesId: seriesId, occurrenceDate: occurrenceDate
        )
    }

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
