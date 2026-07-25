import Testing
import Foundation
@testable import Bovexa

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

    @Test func startIsFormattedAsPocketBaseUtc() {
        let payload = AfwezigCreatePayload(
            owner: "u1", org: "", title: "Ziek", calendar: "private",
            visibility: "private", start: date(), rawInput: "afwezig: ziek"
        )
        #expect((payload.requestBody["start"] as? String)?.hasSuffix("Z") == true)
    }
}
