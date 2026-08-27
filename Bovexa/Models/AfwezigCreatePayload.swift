import Foundation

/// Create-payload voor één afwezig-dag — geport uit save() in
/// ~/Desktop/agenda-app/src/app/afwezig.tsx (valkuil I). Andere vorm dan
/// AppointmentCreatePayload: geen end/viewers/assignee/reminder, wel status_label.
struct AfwezigCreatePayload {
    let owner: String
    let org: String
    let title: String
    let calendar: String
    let visibility: String
    let start: Date
    /// Niet-nil ⇒ dagdeel (m7 plak 5): all_day wordt false en end gaat mee.
    let end: Date?
    let rawInput: String
    /// Wie het blok mag zien. Een doorgegeven beschikbaarheid of afwezigheid is
    /// niet voor de hele ploeg: alleen jijzelf en de beheerder staan hierin, en
    /// dan hoort `visibility` op "people" te staan.
    let viewers: [String]
    /// De beheerder(s) die het moeten goedkeuren. Zij krijgen het blok bij hun
    /// meldingen te zien, met een knop om akkoord te geven of te weigeren.
    let assignee: [String]
    /// Beginstand van de goedkeuring: elke beheerder staat op "pending" tot hij
    /// reageert. Zelfde veld als bij een gewone toewijzing, dus het bestaande
    /// meldingenscherm pikt het vanzelf op.
    let assigneeStatus: [String: String]
    /// Vrije opmerking van de aanvrager, bijvoorbeeld "tandarts". Leeg laten stuurt
    /// het veld niet mee.
    let notes: String

    init(
        owner: String, org: String, title: String, calendar: String, visibility: String,
        start: Date, end: Date? = nil, rawInput: String, viewers: [String] = [],
        assignee: [String] = [], assigneeStatus: [String: String] = [:], notes: String = ""
    ) {
        self.owner = owner
        self.org = org
        self.title = title
        self.calendar = calendar
        self.visibility = visibility
        self.start = start
        self.end = end
        self.rawInput = rawInput
        self.viewers = viewers
        self.assignee = assignee
        self.assigneeStatus = assigneeStatus
        self.notes = notes
    }

    var requestBody: [String: Any] {
        var body: [String: Any] = [
            "owner": owner,
            "org": org,
            "title": title,
            "category": "afwezig",
            "calendar": calendar,
            "visibility": visibility,
            "status_label": "free",
            "all_day": end == nil,
            "start": PBDate.format(start),
            "source": "nl",
            "raw_input": rawInput,
        ]
        if let end { body["end"] = PBDate.format(end) }
        if !viewers.isEmpty { body["viewers"] = viewers }
        let schoneNotitie = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !schoneNotitie.isEmpty { body["notes"] = schoneNotitie }
        if !assignee.isEmpty {
            body["assignee"] = assignee
            body["assignee_status"] = assigneeStatus
        }
        return body
    }
}
