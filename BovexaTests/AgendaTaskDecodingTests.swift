import Testing
import Foundation
@testable import Bovexa

struct AgendaTaskDecodingTests {
    @Test func decodeCompletedAt() throws {
        let json = """
        {"id":"t1","owner":"u1","title":"Taak","status":"klaar","viewers":[],
         "created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z",
         "completed_at":"2026-07-24 09:05:00.000Z"}
        """.data(using: .utf8)!
        let task = try JSONDecoder().decode(AgendaTask.self, from: json)
        #expect(task.completedAt != nil)
    }

    @Test func missingCompletedAtDefaultsToNilWithoutCrashing() throws {
        let json = """
        {"id":"t1","owner":"u1","title":"Taak","status":"open","viewers":[],
         "created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z"}
        """.data(using: .utf8)!
        let task = try JSONDecoder().decode(AgendaTask.self, from: json)
        #expect(task.completedAt == nil)
    }

    @Test func decodeCompletedBy() throws {
        let json = """
        {"id":"t1","owner":"u1","title":"Taak","status":"klaar","viewers":[],
         "created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z",
         "completed_at":"2026-07-24 09:05:00.000Z","completed_by":"u2"}
        """.data(using: .utf8)!
        let task = try JSONDecoder().decode(AgendaTask.self, from: json)
        #expect(task.completedBy == "u2")
    }

    /// PocketBase stuurt een lege relatie als "" terug; dat is geen persoon.
    @Test func legeCompletedByWordtNil() throws {
        let json = """
        {"id":"t1","owner":"u1","title":"Taak","status":"open","viewers":[],
         "created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z",
         "completed_by":""}
        """.data(using: .utf8)!
        let task = try JSONDecoder().decode(AgendaTask.self, from: json)
        #expect(task.completedBy == nil)
    }

    @Test func ontbrekendeCompletedByGeeftNilZonderCrash() throws {
        let json = """
        {"id":"t1","owner":"u1","title":"Taak","status":"klaar","viewers":[],
         "created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z"}
        """.data(using: .utf8)!
        let task = try JSONDecoder().decode(AgendaTask.self, from: json)
        #expect(task.completedBy == nil)
    }

    /// Uitvinken wist beide velden, ook als de aanroeper een naam meegeeft.
    @Test func withStatusOpenWistCompletedAtEnCompletedBy() throws {
        let json = """
        {"id":"t1","owner":"u1","title":"Taak","status":"klaar","viewers":[],
         "created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z",
         "completed_at":"2026-07-24 09:05:00.000Z","completed_by":"u2"}
        """.data(using: .utf8)!
        let task = try JSONDecoder().decode(AgendaTask.self, from: json)
        let heropend = task.withStatus(.open, completedAt: Date(), completedBy: "u3")
        #expect(heropend.completedAt == nil)
        #expect(heropend.completedBy == nil)
    }
}
