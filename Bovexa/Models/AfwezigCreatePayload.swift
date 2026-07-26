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

    init(owner: String, org: String, title: String, calendar: String, visibility: String, start: Date, end: Date? = nil, rawInput: String) {
        self.owner = owner
        self.org = org
        self.title = title
        self.calendar = calendar
        self.visibility = visibility
        self.start = start
        self.end = end
        self.rawInput = rawInput
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
        return body
    }
}
