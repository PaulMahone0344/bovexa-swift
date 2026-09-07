import Testing
import Foundation
@testable import Bovexa

/// Het json-veld `reminders` op agenda_events (punt 15, server 7 sep 2026):
/// decoderen met terugval op reminder_min, en meeschrijven in beide payloads.
struct RemindersVeldTests {
    private func event(json: String) throws -> AgendaEvent {
        try JSONDecoder().decode(AgendaEvent.self, from: json.data(using: .utf8)!)
    }

    private let basis = """
    "id":"ev1","owner":"u1","title":"Kapper","start":"2026-07-24 09:00:00.000Z","all_day":false
    """

    // MARK: - Decoderen

    @Test func remindersListIsDecodedSortedAndDeduped() throws {
        let e = try event(json: "{\(basis),\"reminder_min\":15,\"reminders\":[60,15,15]}")
        #expect(e.reminders == [15, 60])
        #expect(e.reminderMin == 15)
    }

    @Test func missingRemindersFallsBackToReminderMin() throws {
        let e = try event(json: "{\(basis),\"reminder_min\":60}")
        #expect(e.reminders == [60])
    }

    /// PocketBase geeft een leeg json-veld terug als `[]`; dan telt reminder_min nog.
    @Test func emptyRemindersFallsBackToReminderMin() throws {
        let e = try event(json: "{\(basis),\"reminder_min\":15,\"reminders\":[]}")
        #expect(e.reminders == [15])
    }

    @Test func withoutAnyReminderTheListIsEmpty() throws {
        let e = try event(json: "{\(basis)}")
        #expect(e.reminders.isEmpty)
        #expect(e.reminderMin == nil)
    }

    /// Een onverwacht type mag nooit crashen (zelfde regel als de rest van
    /// AgendaEvent.init(from:)); dan valt hij terug op reminder_min.
    @Test func unexpectedRemindersShapeDoesNotCrash() throws {
        let e = try event(json: "{\(basis),\"reminder_min\":15,\"reminders\":\"15\"}")
        #expect(e.reminders == [15])
    }

    @Test func occurrenceCopyKeepsTheWholeList() throws {
        let e = try event(json: "{\(basis),\"reminder_min\":15,\"reminders\":[15,60]}")
        let kopie = e.withOccurrence(id: "ev1:2026-07-25", start: e.start, end: nil, seriesId: "ev1", occurrenceDate: "2026-07-25")
        #expect(kopie.reminders == [15, 60])
    }

    // MARK: - Meeschrijven

    private func datum(_ h: Int) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 8; comps.day = 3; comps.hour = h
        comps.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    @Test func updateBodyCarriesTheListAndTheSmallestAsReminderMin() {
        let payload = EventUpdatePayload(
            title: "T", category: .work, start: datum(9), end: datum(10), notes: "",
            klantNaam: "", klantTelefoon: "", reminders: [60, 15], assignee: [], viewers: [],
            assigneeStatus: [:]
        )
        #expect(payload.requestBody["reminders"] as? [Int] == [15, 60])
        #expect(payload.requestBody["reminder_min"] as? Int == 15)
    }

    @Test func createBodyCarriesTheListAndTheSmallestAsReminderMin() {
        let payload = AppointmentPayloadBuilder.buildManual(
            title: "T", category: .work, start: datum(9), end: datum(10), ownerId: "u1",
            org: "org1", visibility: "private", assignees: [], reminders: [1440, 15, 60]
        )
        #expect(payload.reminders == [15, 60, 1440])
        #expect(payload.requestBody["reminders"] as? [Int] == [15, 60, 1440])
        #expect(payload.requestBody["reminder_min"] as? Int == 15)
    }

    /// Geen herinnering blijft een lege lijst plus reminder_min 0: zo maakt een
    /// wijziging het serverveld ook echt leeg in plaats van de oude lijst te laten staan.
    @Test func noReminderClearsBothFields() {
        let payload = EventUpdatePayload(
            title: "T", category: nil, start: datum(9), end: datum(10), notes: "",
            klantNaam: "", klantTelefoon: "", reminders: [], assignee: [], viewers: [],
            assigneeStatus: [:]
        )
        #expect(payload.requestBody["reminders"] as? [Int] == [])
        #expect(payload.requestBody["reminder_min"] as? Int == 0)
    }

    @Test func editorReadsTheWholeListFromTheEvent() async {
        let e = try! event(json: "{\(basis),\"reminder_min\":15,\"reminders\":[15,60]}")
        let vm = await EventEditorViewModel(event: e, token: "tok")
        #expect(await vm.reminderMinuten == [15, 60])
    }

    @Test func editorFallsBackToReminderMinForAnOldEvent() async {
        let e = try! event(json: "{\(basis),\"reminder_min\":60}")
        let vm = await EventEditorViewModel(event: e, token: "tok")
        #expect(await vm.reminderMinuten == [60])
    }
}
