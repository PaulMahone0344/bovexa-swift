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
    /// Gekozen label-id (m7). Ontbreekt de keuze: veld weglaten (valkuil H —
    /// bestaand gedrag mag niet veranderen zonder label).
    let label: String?
    /// Gekozen contact-id (m8). Aanwezig ⇒ klant_naam/klant_telefoon blijven weg
    /// (valkuil D: die twee zijn alleen voor afspraken zonder contact).
    let contact: String?

    init(
        owner: String, org: String, title: String, category: BovexaTheme.Category, calendar: String,
        location: String, recurrence: String, klantNaam: String, klantTelefoon: String, start: Date, end: Date,
        visibility: String, viewers: [String], assignee: [String], rawInput: String, reminderMin: Int,
        assigneeStatus: [String: String], label: String? = nil, contact: String? = nil
    ) {
        self.owner = owner
        self.org = org
        self.title = title
        self.category = category
        self.calendar = calendar
        self.location = location
        self.recurrence = recurrence
        self.klantNaam = klantNaam
        self.klantTelefoon = klantTelefoon
        self.start = start
        self.end = end
        self.visibility = visibility
        self.viewers = viewers
        self.assignee = assignee
        self.rawInput = rawInput
        self.reminderMin = reminderMin
        self.assigneeStatus = assigneeStatus
        self.label = label
        self.contact = contact
    }

    var requestBody: [String: Any] {
        var body: [String: Any] = [
            "owner": owner,
            "org": org,
            "title": title,
            "category": category.rawValue,
            "calendar": calendar,
            "location": location,
            "recurrence": recurrence,
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
        if let contact {
            body["contact"] = contact
        } else {
            body["klant_naam"] = klantNaam
            body["klant_telefoon"] = klantTelefoon
        }
        if let label { body["label"] = label }
        return body
    }
}
