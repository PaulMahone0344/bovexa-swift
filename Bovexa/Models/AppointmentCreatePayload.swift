import Foundation

/// Create-payload voor een nieuwe afspraak → agenda_events — valkuil A: exact deze
/// velden. Beide aanmaakroutes vullen 'm: de AI-planner (source 'nl') en het
/// handmatige formulier (source 'manual', M12).
struct AppointmentCreatePayload {
    let owner: String
    let org: String
    let title: String
    /// Leeg mag: een afspraak zonder categorie ("Leeg" in de categorierij).
    let category: BovexaTheme.Category?
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
    /// Alle gekozen herinneringen. `reminder_min` gaat er als kleinste waarde naast
    /// mee, want de RN-app kent alleen dat ene veld.
    let reminders: [Int]
    var reminderMin: Int { reminders.first ?? 0 }
    let assigneeStatus: [String: String]
    /// PB-select met exact twee toegestane waarden: 'nl' (AI-planner) en 'manual'
    /// (handmatig formulier). 'ai' geeft een 400 — validation_invalid_value.
    let source: String
    /// Gekozen label-id (m7). Ontbreekt de keuze: veld weglaten (valkuil H —
    /// bestaand gedrag mag niet veranderen zonder label).
    let label: String?
    /// Gekozen contact-id (m8). Aanwezig ⇒ klant_naam/klant_telefoon blijven weg
    /// (valkuil D: die twee zijn alleen voor afspraken zonder contact).
    let contact: String?
    /// Alle gekozen contacten (relatieveld `contacten`). De eerste is dezelfde als
    /// `contact` — die blijft de klant — de rest zijn medegenodigden.
    let contacten: [String]
    /// Notitie uit het handmatige formulier (M12). De AI-planner kent dit veld niet
    /// en laat het weg; leeg of nil ⇒ veld blijft uit de body, zodat beide takken
    /// voor dezelfde invoer dezelfde body schrijven.
    let notes: String?

    init(
        owner: String, org: String, title: String, category: BovexaTheme.Category?, calendar: String,
        location: String, recurrence: String, klantNaam: String, klantTelefoon: String, start: Date, end: Date,
        visibility: String, viewers: [String], assignee: [String], rawInput: String, reminders: [Int],
        assigneeStatus: [String: String], source: String = "nl", label: String? = nil, contact: String? = nil,
        contacten: [String] = [], notes: String? = nil
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
        self.reminders = ReminderOption.opschonen(reminders)
        self.assigneeStatus = assigneeStatus
        self.source = source
        self.label = label
        self.contact = contact
        self.contacten = contacten
        self.notes = notes
    }

    var requestBody: [String: Any] {
        var body: [String: Any] = [
            "owner": owner,
            "org": org,
            "title": title,
            "category": category?.rawValue ?? "",
            "calendar": calendar,
            "location": location,
            "recurrence": recurrence,
            "start": PBDate.format(start),
            "end": PBDate.format(end),
            "visibility": visibility,
            "viewers": viewers,
            "assignee": assignee,
            "source": source,
            "raw_input": rawInput,
            "reminder_min": reminderMin,
            "reminders": reminders,
            "assignee_status": assigneeStatus,
        ]
        // Zie EventUpdatePayload: de naam reist altijd mee, want een collega kan het
        // privécontact zelf niet uitlezen.
        body["klant_naam"] = klantNaam
        body["klant_telefoon"] = klantTelefoon
        if let contact { body["contact"] = contact }
        if !contacten.isEmpty { body["contacten"] = contacten }
        if let label { body["label"] = label }
        if let notes, !notes.isEmpty { body["notes"] = notes }
        return body
    }
}
