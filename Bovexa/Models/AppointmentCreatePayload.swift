import Foundation

/// Create-payload voor een AI-voorstel → agenda_events — valkuil A: exact deze velden,
/// veld "source" altijd 'nl' ('ai' geeft een 400 — validation_invalid_value).
struct AppointmentCreatePayload {
    let owner: String
    let org: String
    let title: String
    let category: BovexaTheme.Category
    let calendar: String // "work" | "private"
    let location: String
    let recurrence: String
    let klantNaam: String
    let klantTelefoon: String
    let start: Date
    let end: Date
    let visibility: String // private | company | people | busy
    let viewers: [String]
    let assignee: [String]
    let rawInput: String
    let reminderMin: Int
    let assigneeStatus: [String: String]

    var requestBody: [String: Any] {
        [
            "owner": owner,
            "org": org,
            "title": title,
            "category": category.rawValue,
            "calendar": calendar,
            "location": location,
            "recurrence": recurrence,
            "klant_naam": klantNaam,
            "klant_telefoon": klantTelefoon,
            "start": PBDate.format(start),
            "end": PBDate.format(end),
            "visibility": visibility,
            "viewers": viewers,
            "assignee": assignee,
            "source": "nl",
            "raw_input": rawInput,
            "reminder_min": reminderMin,
            "assignee_status": assigneeStatus,
        ]
    }
}
