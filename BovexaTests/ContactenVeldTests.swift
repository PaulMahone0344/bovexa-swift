import Testing
import Foundation
@testable import Bovexa

/// Het relatieveld `contacten` op agenda_events (punt 13a, server 7 sep 2026):
/// alle aangevinkte contacten meesturen, de eerste blijft de klant.
struct ContactenVeldTests {
    private func event(json: String) throws -> AgendaEvent {
        try JSONDecoder().decode(AgendaEvent.self, from: json.data(using: .utf8)!)
    }

    private let basis = """
    "id":"ev1","owner":"u1","title":"Kapper","start":"2026-07-24 09:00:00.000Z","all_day":false
    """

    // MARK: - Decoderen

    @Test func allContactIdsAreDecoded() throws {
        let e = try event(json: "{\(basis),\"contact\":\"c1\",\"contacten\":[\"c1\",\"c2\"]}")
        #expect(e.contacten == ["c1", "c2"])
        #expect(e.contact == "c1")
    }

    /// Afspraak van vóór het veld: dan is het ene contact ook de hele lijst.
    @Test func missingContactenFallsBackToTheSingleContact() throws {
        let e = try event(json: "{\(basis),\"contact\":\"c1\"}")
        #expect(e.contacten == ["c1"])
    }

    @Test func withoutAnyContactTheListIsEmpty() throws {
        let e = try event(json: "{\(basis)}")
        #expect(e.contacten.isEmpty)
    }

    /// PocketBase geeft een lege relatie als "" of [] terug; dat mag geen lege
    /// id in de lijst opleveren.
    @Test func emptyRelationValuesAreDropped() throws {
        let e = try event(json: "{\(basis),\"contact\":\"\",\"contacten\":[]}")
        #expect(e.contacten.isEmpty)
    }

    @Test func expandedContactsAreDecodedAsAList() throws {
        let json = """
        {\(basis),"contact":"c1","contacten":["c1","c2"],
         "expand":{"contact":{"id":"c1","naam":"Jan"},
                   "contacten":[{"id":"c1","naam":"Jan"},{"id":"c2","naam":"Piet"}]}}
        """
        let e = try event(json: json)
        #expect(ContactDisplay.namen(for: e) == ["Jan", "Piet"])
    }

    /// Zonder expand (of bij een oude afspraak) blijft het bij de ene regel die er
    /// altijd al stond — de klantnaam.
    @Test func withoutExpandTheKlantNameIsTheOnlyLine() throws {
        let e = try event(json: "{\(basis),\"klant_naam\":\"Jansen\"}")
        #expect(ContactDisplay.namen(for: e) == ["Jansen"])
    }

    @Test func withoutAnyNameThereIsNoContactLine() throws {
        let e = try event(json: "{\(basis)}")
        #expect(ContactDisplay.namen(for: e).isEmpty)
    }

    // MARK: - Meeschrijven

    private func datum(_ h: Int) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 8; comps.day = 3; comps.hour = h
        comps.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    @Test func updateBodyCarriesEveryChosenContact() {
        let payload = EventUpdatePayload(
            title: "T", category: .work, start: datum(9), end: datum(10), notes: "",
            klantNaam: "Jan", klantTelefoon: "", reminders: [], assignee: [], viewers: [],
            assigneeStatus: [:], contact: "c1", contacten: ["c1", "c2"]
        )
        #expect(payload.requestBody["contact"] as? String == "c1")
        #expect(payload.requestBody["contacten"] as? [String] == ["c1", "c2"])
    }

    /// Alle contacten losmaken moet het serverveld ook echt leegmaken.
    @Test func updateBodyClearsContactenWhenNothingIsChosen() {
        let payload = EventUpdatePayload(
            title: "T", category: .work, start: datum(9), end: datum(10), notes: "",
            klantNaam: "", klantTelefoon: "", reminders: [], assignee: [], viewers: [],
            assigneeStatus: [:]
        )
        #expect(payload.requestBody["contact"] == nil)
        #expect(payload.requestBody["contacten"] as? [String] == [])
    }

    @Test func manualCreateBodyCarriesEveryChosenContact() {
        let payload = AppointmentPayloadBuilder.buildManual(
            title: "T", category: .work, start: datum(9), end: datum(10), ownerId: "u1",
            org: "org1", visibility: "private", assignees: [], reminders: [],
            contact: "c1", contacten: ["c1", "c2"]
        )
        #expect(payload.requestBody["contacten"] as? [String] == ["c1", "c2"])
    }

    /// Zonder contacten blijft het veld uit de create-body: beide aanmaakroutes
    /// moeten voor dezelfde invoer dezelfde body schrijven.
    @Test func createBodyOmitsContactenWhenNothingIsChosen() {
        let payload = AppointmentPayloadBuilder.buildManual(
            title: "T", category: .work, start: datum(9), end: datum(10), ownerId: "u1",
            org: "org1", visibility: "private", assignees: [], reminders: []
        )
        #expect(payload.requestBody["contacten"] == nil)
    }

    // MARK: - Formulier

    @Test func editorReadsEveryContactFromTheEvent() async {
        let e = try! event(json: "{\(basis),\"contact\":\"c1\",\"contacten\":[\"c1\",\"c2\"]}")
        let vm = await EventEditorViewModel(event: e, token: "tok")
        #expect(await vm.contactIds == ["c1", "c2"])
        #expect(await vm.contactId == "c1")
    }

    @Test func selectingSeveralContactsKeepsTheFirstAsKlant() async {
        let e = try! event(json: "{\(basis)}")
        let vm = await EventEditorViewModel(event: e, token: "tok")
        await vm.selectContacts([
            AgendaContact(id: "c1", eigenaar: "u1", naam: "Jan", telefoon: "0611", notitie: ""),
            AgendaContact(id: "c2", eigenaar: "u1", naam: "Piet", telefoon: "0622", notitie: ""),
        ])
        #expect(await vm.contactIds == ["c1", "c2"])
        #expect(await vm.klantNaam == "Jan")
        #expect(await vm.klantTelefoon == "0611")
    }
}
