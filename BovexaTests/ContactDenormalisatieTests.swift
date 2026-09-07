import Testing
import Foundation
@testable import Bovexa

/// Een privécontact is alleen leesbaar voor de eigenaar (leesregel eigenaar =
/// ingelogde gebruiker). Zonder de naam óók als klant_naam mee te schrijven ziet een
/// collega op een gedeelde afspraak geen klant meer, en valt die afspraak uit zijn
/// Klanten-scherm. Deze tests bewaken die kopie.
struct ContactDenormalisatieTests {
    private func date(_ h: Int) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 8; comps.day = 3; comps.hour = h
        comps.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    private func contact(naam: String = "Bakker Jansen", telefoon: String = "0612345678") -> AgendaContact {
        AgendaContact(id: "c1", eigenaar: "u1", naam: naam, telefoon: telefoon, notitie: "")
    }

    @Test func updatePayloadKeepsKlantNaamAlongsideContact() {
        let payload = EventUpdatePayload(
            title: "Onderhoud", category: .work, start: date(9), end: date(10),
            notes: "", klantNaam: "Bakker Jansen", klantTelefoon: "0612345678",
            reminders: [], assignee: [], viewers: [], assigneeStatus: [:], contact: "c1"
        )
        let body = payload.requestBody
        #expect(body["contact"] as? String == "c1")
        #expect(body["klant_naam"] as? String == "Bakker Jansen")
        #expect(body["klant_telefoon"] as? String == "0612345678")
    }

    @Test func createPayloadKeepsKlantNaamAlongsideContact() {
        let payload = AppointmentCreatePayload(
            owner: "u1", org: "org1", title: "Onderhoud", category: .work, calendar: "work",
            location: "", recurrence: "", klantNaam: "Bakker Jansen", klantTelefoon: "0612345678",
            start: date(9), end: date(10), visibility: "company", viewers: [], assignee: [],
            rawInput: "raw", reminders: [], assigneeStatus: [:], contact: "c1"
        )
        let body = payload.requestBody
        #expect(body["contact"] as? String == "c1")
        #expect(body["klant_naam"] as? String == "Bakker Jansen")
    }

    @Test func plannerBuilderPrefersContactNameOverParsedName() {
        let appointment = ProposedAppointment(
            title: "Onderhoud", date: "2026-08-03", start: "09:00", end: "09:30",
            category: .work, location: nil, recurrence: nil
        )
        let payload = AppointmentPayloadBuilder.build(
            appointment: appointment, ownerId: "u1", rawInput: "raw", org: "org1",
            visibility: "company", viewers: [], assignees: [], reminders: [],
            contact: "c1", contactNaam: "Bakker Jansen", contactTelefoon: "0612345678"
        )
        #expect(payload.requestBody["klant_naam"] as? String == "Bakker Jansen")
        #expect(payload.requestBody["contact"] as? String == "c1")
    }

    @MainActor
    @Test func editorSelectContactFillsNameAndPhone() {
        let event = AgendaEvent(
            id: "ev1", owner: "u1", calendar: nil, category: .work, title: "Onderhoud",
            start: date(9), end: date(10), allDay: false, recurrence: nil, location: nil,
            notes: "", klantNaam: "Oude tekst", assigneeStatus: [:], seriesId: nil, occurrenceDate: nil
        )
        let vm = EventEditorViewModel(
            event: event, token: "tok",
            repository: EventRepository(client: PBClient(session: URLProtocolStub.makeSession())),
            reminderService: ReminderService(scheduler: FakeNotificationScheduler())
        )
        vm.selectContact(contact())
        #expect(vm.contactId == "c1")
        #expect(vm.klantNaam == "Bakker Jansen")
        #expect(vm.klantTelefoon == "0612345678")
    }

    @MainActor
    @Test func editorReleasingContactRestoresOriginalText() {
        let event = AgendaEvent(
            id: "ev1", owner: "u1", calendar: nil, category: .work, title: "Onderhoud",
            start: date(9), end: date(10), allDay: false, recurrence: nil, location: nil,
            notes: "", klantNaam: "Oude tekst", assigneeStatus: [:], seriesId: nil, occurrenceDate: nil
        )
        let vm = EventEditorViewModel(
            event: event, token: "tok",
            repository: EventRepository(client: PBClient(session: URLProtocolStub.makeSession())),
            reminderService: ReminderService(scheduler: FakeNotificationScheduler())
        )
        vm.selectContact(contact())
        vm.selectContact(nil)
        #expect(vm.contactId == nil)
        #expect(vm.klantNaam == "Oude tekst")
    }
}
