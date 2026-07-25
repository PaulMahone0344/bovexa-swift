import Testing
import Foundation
@testable import Bovexa

/// Response-fixtures (valkuil B) — vraag om verduidelijking, klaar plan, en rommel
/// die geweigerd moet worden. Vorm 1:1 uit isPlanResponse/isAppointment in
/// ~/Desktop/agenda-app/src/lib/aiPlanner.ts.
struct PlanResponseDecodingTests {
    private func decode(_ json: String) throws -> PlanResponse {
        try JSONDecoder().decode(PlanResponse.self, from: Data(json.utf8))
    }

    @Test func decodesNeedsClarificationWithOptions() throws {
        let json = """
        {"status":"needs_clarification","message":"Welke dag bedoel je?","question":"Welke dag?",
         "options":["Morgen","Overmorgen"],"appointments":[]}
        """
        let plan = try decode(json)
        #expect(plan.status == .needsClarification)
        #expect(plan.question == "Welke dag?")
        #expect(plan.options == ["Morgen", "Overmorgen"])
        #expect(plan.appointments.isEmpty)
    }

    @Test func decodesReadyPlanWithAppointments() throws {
        let json = """
        {"status":"ready","message":"Klaar!","question":null,"options":[],
         "appointments":[{"title":"Tandarts","date":"2026-08-03","start":"09:00","end":"09:30","category":"body"}]}
        """
        let plan = try decode(json)
        #expect(plan.status == .ready)
        #expect(plan.appointments.count == 1)
        #expect(plan.appointments[0].title == "Tandarts")
        #expect(plan.appointments[0].category == .body)
    }

    @Test func decodesOptionalAppointmentFieldsWhenPresent() throws {
        let json = """
        {"status":"ready","message":"Klaar!","question":null,"options":[],
         "appointments":[{"title":"Klant Jansen","date":"2026-08-03","start":"09:00","end":"09:30",
         "category":"work","location":"Kantoor","recurrence":"FREQ=WEEKLY","klant_naam":"Jansen","klant_telefoon":"0612345678"}]}
        """
        let plan = try decode(json)
        let a = plan.appointments[0]
        #expect(a.location == "Kantoor")
        #expect(a.recurrence == "FREQ=WEEKLY")
        #expect(a.klantNaam == "Jansen")
        #expect(a.klantTelefoon == "0612345678")
    }

    @Test func rejectsUnknownCategory() {
        let json = """
        {"status":"ready","message":"Klaar!","question":null,"options":[],
         "appointments":[{"title":"T","date":"2026-08-03","start":"09:00","end":"09:30","category":"afwezig"}]}
        """
        #expect(throws: (any Error).self) { try decode(json) }
    }

    @Test func rejectsGarbageCategory() {
        let json = """
        {"status":"ready","message":"Klaar!","question":null,"options":[],
         "appointments":[{"title":"T","date":"2026-08-03","start":"09:00","end":"09:30","category":"rommel"}]}
        """
        #expect(throws: (any Error).self) { try decode(json) }
    }

    @Test func rejectsUnknownStatus() {
        let json = """
        {"status":"rommel","message":"?","question":null,"options":[],"appointments":[]}
        """
        #expect(throws: (any Error).self) { try decode(json) }
    }

    @Test func rejectsMissingRequiredField() {
        let json = """
        {"status":"ready","message":"Klaar!","question":null,"options":[],
         "appointments":[{"date":"2026-08-03","start":"09:00","end":"09:30","category":"work"}]}
        """
        #expect(throws: (any Error).self) { try decode(json) }
    }

    @Test func rejectsWrongTypeForOptions() {
        let json = """
        {"status":"needs_clarification","message":"?","question":null,"options":[1,2],"appointments":[]}
        """
        #expect(throws: (any Error).self) { try decode(json) }
    }
}
