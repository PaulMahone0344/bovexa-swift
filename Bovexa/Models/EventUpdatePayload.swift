import Foundation

/// Update-payload voor EventRepository.updateEvent — valkuil E: exact deze velden,
/// veld "source" nooit aanraken, datums in PocketBase-formaat (UTC).
struct EventUpdatePayload {
    let title: String
    let category: BovexaTheme.Category
    let start: Date
    let end: Date
    let notes: String
    let klantNaam: String
    let klantTelefoon: String
    let reminderMin: Int
    let assignee: [String]
    let viewers: [String]
    let assigneeStatus: [String: String]
    /// Gekozen label-id (m7). Ontbreekt de keuze: veld weglaten, niet leegmaken
    /// (plan: "geen label laat het veld weg").
    let label: String?

    init(
        title: String, category: BovexaTheme.Category, start: Date, end: Date, notes: String,
        klantNaam: String, klantTelefoon: String, reminderMin: Int, assignee: [String],
        viewers: [String], assigneeStatus: [String: String], label: String? = nil
    ) {
        self.title = title
        self.category = category
        self.start = start
        self.end = end
        self.notes = notes
        self.klantNaam = klantNaam
        self.klantTelefoon = klantTelefoon
        self.reminderMin = reminderMin
        self.assignee = assignee
        self.viewers = viewers
        self.assigneeStatus = assigneeStatus
        self.label = label
    }

    var requestBody: [String: Any] {
        var body: [String: Any] = [
            "title": title,
            "category": category.rawValue,
            "start": PBDate.format(start),
            "end": PBDate.format(end),
            "notes": notes,
            "klant_naam": klantNaam,
            "klant_telefoon": klantTelefoon,
            "reminder_min": reminderMin,
            "assignee": assignee,
            "viewers": viewers,
            "assignee_status": assigneeStatus,
        ]
        if let label { body["label"] = label }
        return body
    }
}
