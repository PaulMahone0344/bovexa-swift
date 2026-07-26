import Testing
import Foundation
@testable import Bovexa

struct AgendaEventDecodingTests {
    @Test func decodeFullFixture() throws {
        let json = """
        {
          "id": "ev1", "owner": "u1", "org": "org1", "calendar": "work", "category": "work",
          "title": "Klant Jansen", "start": "2026-07-24 09:00:00.000Z",
          "end": "2026-07-24 10:00:00.000Z", "all_day": false,
          "location": "Tiel", "notes": "Meenemen: offerte", "visibility": "company",
          "viewers": ["u2", "u3"], "assignee": ["u2"], "reminder_min": 15,
          "klant_naam": "Jansen", "klant_telefoon": "0612345678",
          "assignee_status": {"u2": "accepted"}
        }
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(AgendaEvent.self, from: json)
        #expect(event.id == "ev1")
        #expect(event.owner == "u1")
        #expect(event.org == "org1")
        #expect(event.category == .work)
        #expect(event.title == "Klant Jansen")
        #expect(event.location == "Tiel")
        #expect(event.klantNaam == "Jansen")
        #expect(event.klantTelefoon == "0612345678")
        #expect(event.visibilityRaw == "company")
        #expect(event.viewers == ["u2", "u3"])
        #expect(event.assignee == ["u2"])
        #expect(event.reminderMin == 15)
        #expect(event.assigneeStatus["u2"] == "accepted")
        #expect(event.end != nil)
        #expect(event.allDay == false)
    }

    @Test func decodeAssigneeAsLegacySingleStringNormalizesToArray() throws {
        // Oudere records hadden een los string-id i.p.v. een array (vóór punt F).
        let json = """
        {"id":"ev1","owner":"u1","title":"Iets","start":"2026-07-24 09:00:00.000Z","all_day":false,"assignee":"u2"}
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(AgendaEvent.self, from: json)
        #expect(event.assignee == ["u2"])
    }

    @Test func decodeMissingAssigneeAndViewersDefaultToEmptyArray() throws {
        let json = """
        {"id":"ev1","owner":"u1","title":"Iets","start":"2026-07-24 09:00:00.000Z","all_day":false}
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(AgendaEvent.self, from: json)
        #expect(event.assignee.isEmpty)
        #expect(event.viewers.isEmpty)
        #expect(event.org == nil)
        #expect(event.visibilityRaw == nil)
        #expect(event.reminderMin == nil)
        #expect(event.klantTelefoon == nil)
    }

    @Test func decodeMissingAssigneeStatusDefaultsToEmpty() throws {
        let json = """
        {"id":"ev1","owner":"u1","title":"Iets","start":"2026-07-24 09:00:00.000Z","all_day":false}
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(AgendaEvent.self, from: json)
        #expect(event.assigneeStatus.isEmpty)
    }

    // MARK: - contact (m8)

    @Test func decodeContactAndExpandedContact() throws {
        let json = """
        {"id":"ev1","owner":"u1","title":"Iets","start":"2026-07-24 09:00:00.000Z","all_day":false,
         "contact":"c1","expand":{"contact":{"id":"c1","eigenaar":"u1","naam":"Karim","telefoon":"0611111111","notitie":""}}}
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(AgendaEvent.self, from: json)
        #expect(event.contact == "c1")
        #expect(event.expand?.contact?.naam == "Karim")
    }

    @Test func decodeMissingContactAndExpandDefaultToNil() throws {
        let json = """
        {"id":"ev1","owner":"u1","title":"Iets","start":"2026-07-24 09:00:00.000Z","all_day":false,"klant_naam":"Jansen"}
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(AgendaEvent.self, from: json)
        #expect(event.contact == nil)
        #expect(event.expand == nil)
        #expect(event.klantNaam == "Jansen")
    }

    @Test func decodeUnknownCategoryDoesNotCrashAndIsNil() throws {
        let json = """
        {"id":"ev1","owner":"u1","title":"Iets","start":"2026-07-24 09:00:00.000Z","all_day":false,"category":"onbekend"}
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(AgendaEvent.self, from: json)
        #expect(event.category == nil)
    }

    @Test func decodeOldStringAssigneeStatusShapeDoesNotCrash() throws {
        // valkuil B: oude records kunnen assignee_status ontbreken of afwijkend gevormd zijn.
        let json = """
        {"id":"ev1","owner":"u1","title":"Iets","start":"2026-07-24 09:00:00.000Z","all_day":false,"assignee_status":"kapot"}
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(AgendaEvent.self, from: json)
        #expect(event.assigneeStatus.isEmpty)
    }

    @Test func decodeInvalidStartDoesNotThrow() throws {
        let json = """
        {"id":"ev1","owner":"u1","title":"Iets","start":"niet-een-datum","all_day":false}
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(AgendaEvent.self, from: json)
        #expect(event.id == "ev1")
    }
}
