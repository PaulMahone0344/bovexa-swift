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
    let rawInput: String

    var requestBody: [String: Any] {
        [
            "owner": owner,
            "org": org,
            "title": title,
            "category": "afwezig",
            "calendar": calendar,
            "visibility": visibility,
            "status_label": "free",
            "all_day": true,
            "start": PBDate.format(start),
            "source": "nl",
            "raw_input": rawInput,
        ]
    }
}
