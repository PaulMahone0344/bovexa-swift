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

    var requestBody: [String: Any] {
        [
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
    }
}
