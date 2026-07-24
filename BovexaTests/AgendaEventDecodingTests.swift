import Testing
import Foundation
@testable import Bovexa

struct AgendaEventDecodingTests {
    @Test func decodeFullFixture() throws {
        let json = """
        {
          "id": "ev1", "owner": "u1", "calendar": "work", "category": "work",
          "title": "Klant Jansen", "start": "2026-07-24 09:00:00.000Z",
          "end": "2026-07-24 10:00:00.000Z", "all_day": false,
          "location": "Tiel", "notes": "Meenemen: offerte",
          "klant_naam": "Jansen", "assignee_status": {"u2": "accepted"}
        }
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(AgendaEvent.self, from: json)
        #expect(event.id == "ev1")
        #expect(event.owner == "u1")
        #expect(event.category == .work)
        #expect(event.title == "Klant Jansen")
        #expect(event.location == "Tiel")
        #expect(event.klantNaam == "Jansen")
        #expect(event.assigneeStatus["u2"] == "accepted")
        #expect(event.end != nil)
        #expect(event.allDay == false)
    }

    @Test func decodeMissingAssigneeStatusDefaultsToEmpty() throws {
        let json = """
        {"id":"ev1","owner":"u1","title":"Iets","start":"2026-07-24 09:00:00.000Z","all_day":false}
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(AgendaEvent.self, from: json)
        #expect(event.assigneeStatus.isEmpty)
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
