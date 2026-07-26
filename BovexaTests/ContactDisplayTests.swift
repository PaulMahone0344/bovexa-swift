import Testing
import Foundation
@testable import Bovexa

struct ContactDisplayTests {
    private func event(klantNaam: String?, klantTelefoon: String? = nil, expand: AgendaEvent.Expand? = nil) -> AgendaEvent {
        AgendaEvent(
            id: "ev1", owner: "me", calendar: nil, category: nil, title: "Afspraak",
            start: Date(timeIntervalSince1970: 0), end: nil, allDay: false, recurrence: nil, location: nil, notes: nil,
            klantNaam: klantNaam, assigneeStatus: [:], seriesId: nil, occurrenceDate: nil,
            klantTelefoon: klantTelefoon, contact: expand?.contact?.id, expand: expand
        )
    }

    // MARK: - naam

    @Test func contactNaamWinsOverKlantNaam() {
        let contact = AgendaContact(id: "c1", eigenaar: "u1", naam: "Karim B.", telefoon: "0611111111", notitie: "")
        let event = event(klantNaam: "Karim (tikfout)", expand: AgendaEvent.Expand(contact: contact))
        #expect(ContactDisplay.naam(for: event) == "Karim B.")
    }

    @Test func oldEventWithoutContactFallsBackToKlantNaam() {
        let event = event(klantNaam: "Jansen")
        #expect(ContactDisplay.naam(for: event) == "Jansen")
    }

    @Test func noContactAndNoKlantNaamReturnsNil() {
        let event = event(klantNaam: nil)
        #expect(ContactDisplay.naam(for: event) == nil)
    }

    // MARK: - telefoon

    @Test func contactTelefoonWinsOverKlantTelefoon() {
        let contact = AgendaContact(id: "c1", eigenaar: "u1", naam: "Karim", telefoon: "0622222222", notitie: "")
        let event = event(klantNaam: "Karim", klantTelefoon: "0611111111", expand: AgendaEvent.Expand(contact: contact))
        #expect(ContactDisplay.telefoon(for: event) == "0622222222")
    }

    @Test func emptyContactTelefoonFallsBackToKlantTelefoon() {
        let contact = AgendaContact(id: "c1", eigenaar: "u1", naam: "Karim", telefoon: "", notitie: "")
        let event = event(klantNaam: "Karim", klantTelefoon: "0611111111", expand: AgendaEvent.Expand(contact: contact))
        #expect(ContactDisplay.telefoon(for: event) == "0611111111")
    }
}
