import Testing
import Foundation
@testable import Bovexa

/// Valkuil E: exact deze velden, veld "source" nooit aanraken, datums in PB-formaat (UTC).
struct EventUpdatePayloadTests {
    private func date(_ h: Int, _ min: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 8; comps.day = 3; comps.hour = h; comps.minute = min
        comps.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    @Test func requestBodyContainsExactlyTheValkuilEFields() {
        let payload = EventUpdatePayload(
            title: "Klant Jansen", category: .work, start: date(9), end: date(10),
            notes: "Offerte meenemen", klantNaam: "Jansen", klantTelefoon: "0612345678",
            reminderMin: 15, assignee: ["u2"], viewers: ["u2"], assigneeStatus: ["u2": "pending"]
        )
        let body = payload.requestBody
        #expect(Set(body.keys) == [
            "title", "category", "start", "end", "notes", "klant_naam",
            "klant_telefoon", "reminder_min", "assignee", "viewers", "assignee_status",
        ])
        #expect(body["source"] == nil)
        #expect(body["title"] as? String == "Klant Jansen")
        #expect(body["category"] as? String == "work")
        #expect(body["reminder_min"] as? Int == 15)
        #expect(body["assignee"] as? [String] == ["u2"])
        #expect(body["viewers"] as? [String] == ["u2"])
        #expect(body["assignee_status"] as? [String: String] == ["u2": "pending"])
    }

    @Test func datesAreFormattedInPocketBaseUtcFormat() {
        let payload = EventUpdatePayload(
            title: "T", category: .focus, start: date(9), end: date(10),
            notes: "", klantNaam: "", klantTelefoon: "", reminderMin: 0,
            assignee: [], viewers: [], assigneeStatus: [:]
        )
        let body = payload.requestBody
        #expect(body["start"] as? String == "2026-08-03 09:00:00.000Z")
        #expect(body["end"] as? String == "2026-08-03 10:00:00.000Z")
    }
}
