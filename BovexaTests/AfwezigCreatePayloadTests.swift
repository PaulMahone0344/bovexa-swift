import Testing
import Foundation
@testable import Bovexa

/// AfwezigRange.combine — dagdeel-payload (m7 plak 5): dag uit `day`, uur/minuut uit `time`.
struct AfwezigRangeCombineTests {
    @Test func combineTakesDayFromDayAndTimeFromTime() {
        var dayComps = DateComponents()
        dayComps.year = 2026; dayComps.month = 8; dayComps.day = 3; dayComps.hour = 12
        let day = Calendar(identifier: .gregorian).date(from: dayComps)!

        var timeComps = DateComponents()
        timeComps.year = 2000; timeComps.month = 1; timeComps.day = 1; timeComps.hour = 14; timeComps.minute = 30
        let time = Calendar(identifier: .gregorian).date(from: timeComps)!

        let combined = AfwezigRange.combine(day: day, time: time)
        let result = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day, .hour, .minute], from: combined)
        #expect(result.year == 2026)
        #expect(result.month == 8)
        #expect(result.day == 3)
        #expect(result.hour == 14)
        #expect(result.minute == 30)
    }
}

/// AfwezigCreatePayload.requestBody — valkuil I: exacte velden, category/status_label/
/// all_day/source vast, raw_input met de lowercase reden.
struct AfwezigCreatePayloadTests {
    private func date() -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 8; comps.day = 3; comps.hour = 12
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    @Test func requestBodyContainsFixedFields() {
        let payload = AfwezigCreatePayload(
            owner: "u1", org: "org1", title: "Vakantie", calendar: "work",
            visibility: "company", start: date(), rawInput: "afwezig: vakantie"
        )
        let body = payload.requestBody
        #expect(body["category"] as? String == "afwezig")
        #expect(body["status_label"] as? String == "free")
        #expect(body["all_day"] as? Bool == true)
        #expect(body["source"] as? String == "nl")
        #expect(body["raw_input"] as? String == "afwezig: vakantie")
        #expect(body["title"] as? String == "Vakantie")
        #expect(body["owner"] as? String == "u1")
        #expect(body["org"] as? String == "org1")
        #expect(body["calendar"] as? String == "work")
        #expect(body["visibility"] as? String == "company")
    }

    @Test func withoutEndAllDayStaysTrueAndEndIsOmitted() {
        let payload = AfwezigCreatePayload(
            owner: "u1", org: "org1", title: "Vakantie", calendar: "work",
            visibility: "company", start: date(), rawInput: "afwezig: vakantie"
        )
        #expect(payload.requestBody["all_day"] as? Bool == true)
        #expect(payload.requestBody["end"] == nil)
    }

    @Test func withEndAllDayBecomesFalseAndEndIsIncluded() {
        let end = date().addingTimeInterval(4 * 3600)
        let payload = AfwezigCreatePayload(
            owner: "u1", org: "org1", title: "Vakantie", calendar: "work",
            visibility: "company", start: date(), end: end, rawInput: "afwezig: vakantie"
        )
        #expect(payload.requestBody["all_day"] as? Bool == false)
        #expect((payload.requestBody["end"] as? String)?.hasSuffix("Z") == true)
    }

    @Test func startIsFormattedAsPocketBaseUtc() {
        let payload = AfwezigCreatePayload(
            owner: "u1", org: "", title: "Ziek", calendar: "private",
            visibility: "private", start: date(), rawInput: "afwezig: ziek"
        )
        #expect((payload.requestBody["start"] as? String)?.hasSuffix("Z") == true)
    }
}
