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
}
