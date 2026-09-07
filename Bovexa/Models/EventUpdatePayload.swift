import Foundation

/// Update-payload voor EventRepository.updateEvent — valkuil E: exact deze velden,
/// veld "source" nooit aanraken, datums in PocketBase-formaat (UTC).
struct EventUpdatePayload {
    let title: String
    /// Leeg mag: "Leeg" in de categorierij stuurt een lege waarde mee, zodat de
    /// afspraak zonder categorie in de agenda staat.
    let category: BovexaTheme.Category?
    let start: Date
    let end: Date
    let notes: String
    let klantNaam: String
    let klantTelefoon: String
    /// Alle gekozen herinneringen. `reminder_min` blijft daarnaast bestaan als de
    /// kleinste waarde uit deze lijst, want de RN-app leest alleen dat ene veld.
    let reminders: [Int]
    var reminderMin: Int { reminders.first ?? 0 }
    let assignee: [String]
    let viewers: [String]
    let assigneeStatus: [String: String]
    /// Gekozen label-id (m7). Ontbreekt de keuze: veld weglaten, niet leegmaken
    /// (plan: "geen label laat het veld weg").
    let label: String?
    /// Gekozen contact-id (m8). Aanwezig ⇒ klant_naam/klant_telefoon blijven weg
    /// (valkuil D: die twee zijn alleen voor afspraken zonder contact).
    let contact: String?
    /// Alle gekozen contacten (relatieveld `contacten`). De eerste is dezelfde als
    /// `contact` — die blijft de klant — de rest zijn medegenodigden. Gaat altijd
    /// mee, ook leeg, zodat het losmaken van een contact ook echt doorkomt.
    let contacten: [String]
    /// Wie de afspraak mag zien. Nil laat het veld weg: alleen het bewerkscherm van
    /// een bedrijfsafspraak toont die knoppen, en zonder bedrijf is er niets te
    /// kiezen. Viewers gaan hierboven al mee, dus die blijven kloppen.
    let visibility: String?

    init(
        title: String, category: BovexaTheme.Category?, start: Date, end: Date, notes: String,
        klantNaam: String, klantTelefoon: String, reminders: [Int], assignee: [String],
        viewers: [String], assigneeStatus: [String: String], label: String? = nil, contact: String? = nil,
        contacten: [String] = [], visibility: String? = nil
    ) {
        self.title = title
        self.category = category
        self.start = start
        self.end = end
        self.notes = notes
        self.klantNaam = klantNaam
        self.klantTelefoon = klantTelefoon
        self.reminders = ReminderOption.opschonen(reminders)
        self.assignee = assignee
        self.viewers = viewers
        self.assigneeStatus = assigneeStatus
        self.label = label
        self.contact = contact
        self.contacten = contacten
        self.visibility = visibility
    }

    var requestBody: [String: Any] {
        var body: [String: Any] = [
            "title": title,
            "category": category?.rawValue ?? "",
            "start": PBDate.format(start),
            "end": PBDate.format(end),
            "notes": notes,
            "reminder_min": reminderMin,
            "reminders": reminders,
            "assignee": assignee,
            "viewers": viewers,
            "assignee_status": assigneeStatus,
        ]
        // Naam en telefoon gaan ALTIJD mee, ook met een gekoppeld contact. Contacten
        // zijn privé (leesregel eigenaar = ingelogde gebruiker), dus een collega kan
        // de relatie niet uitlezen; zonder deze kopie ziet hij op een gedeelde
        // afspraak geen klant meer en valt die afspraak uit zijn Klanten-scherm.
        body["klant_naam"] = klantNaam
        body["klant_telefoon"] = klantTelefoon
        if let contact { body["contact"] = contact }
        body["contacten"] = contacten
        if let label { body["label"] = label }
        if let visibility { body["visibility"] = visibility }
        return body
    }
}
