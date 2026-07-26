import Testing
import Foundation
@testable import Bovexa

struct KlantGroupingTests {
    private func event(id: String, klantNaam: String?, klantTelefoon: String? = nil, start: Date, expand: AgendaEvent.Expand? = nil) -> AgendaEvent {
        AgendaEvent(
            id: id, owner: "me", calendar: nil, category: nil, title: "Afspraak \(id)",
            start: start, end: nil, allDay: false, recurrence: nil, location: nil, notes: nil,
            klantNaam: klantNaam, assigneeStatus: [:], seriesId: nil, occurrenceDate: nil,
            klantTelefoon: klantTelefoon, contact: expand?.contact?.id, expand: expand
        )
    }

    private func date(_ offset: TimeInterval) -> Date { Date(timeIntervalSince1970: offset) }

    // MARK: - groepering (valkuil F)

    @Test func groupsEventsCaseInsensitivelyByKlantNaam() {
        let events = [
            event(id: "a", klantNaam: "Jansen", start: date(100)),
            event(id: "b", klantNaam: "jansen", start: date(200)),
        ]
        let groups = KlantGrouping.group(events)
        #expect(groups.count == 1)
        #expect(groups[0].events.map(\.id) == ["a", "b"])
    }

    @Test func eventsWithoutKlantNaamAreExcluded() {
        let events = [
            event(id: "a", klantNaam: nil, start: date(100)),
            event(id: "b", klantNaam: "  ", start: date(200)),
            event(id: "c", klantNaam: "Jansen", start: date(300)),
        ]
        let groups = KlantGrouping.group(events)
        #expect(groups.map(\.naam) == ["Jansen"])
    }

    @Test func firstNonEmptyPhoneIsKept() {
        let events = [
            event(id: "a", klantNaam: "Jansen", klantTelefoon: nil, start: date(100)),
            event(id: "b", klantNaam: "Jansen", klantTelefoon: "0612345678", start: date(200)),
            event(id: "c", klantNaam: "Jansen", klantTelefoon: "0699999999", start: date(300)),
        ]
        let groups = KlantGrouping.group(events)
        #expect(groups[0].telefoon == "0612345678")
    }

    @Test func eventsWithinAGroupAreSortedAscendingByStart() {
        let events = [
            event(id: "later", klantNaam: "Jansen", start: date(300)),
            event(id: "eerder", klantNaam: "Jansen", start: date(100)),
        ]
        let groups = KlantGrouping.group(events)
        #expect(groups[0].events.map(\.id) == ["eerder", "later"])
    }

    @Test func groupsAreSortedAlphabeticallyByNaam() {
        let events = [
            event(id: "a", klantNaam: "Zeeman", start: date(100)),
            event(id: "b", klantNaam: "Albers", start: date(100)),
        ]
        let groups = KlantGrouping.group(events)
        #expect(groups.map(\.naam) == ["Albers", "Zeeman"])
    }

    @Test func emptyEventsProduceEmptyGroups() {
        #expect(KlantGrouping.group([]).isEmpty)
    }

    // MARK: - contact (m8)

    @Test func contactNaamWinsOverTypoedKlantNaamAndDedupesTheGroup() {
        let contact = AgendaContact(id: "c1", eigenaar: "u1", naam: "Van der Berg", telefoon: "0611111111", notitie: "")
        let events = [
            event(id: "a", klantNaam: "Van der Berg", start: date(100), expand: AgendaEvent.Expand(contact: contact)),
            event(id: "b", klantNaam: "van der berg", start: date(200), expand: AgendaEvent.Expand(contact: contact)),
        ]
        let groups = KlantGrouping.group(events)
        #expect(groups.count == 1)
        #expect(groups[0].naam == "Van der Berg")
        #expect(groups[0].events.map(\.id) == ["a", "b"])
    }

    @Test func mixOfContactLinkedAndPlainKlantNaamGroupsCorrectly() {
        let contact = AgendaContact(id: "c1", eigenaar: "u1", naam: "Jansen", telefoon: "", notitie: "")
        let events = [
            event(id: "linked", klantNaam: "Jansen", start: date(100), expand: AgendaEvent.Expand(contact: contact)),
            event(id: "legacy", klantNaam: "Jansen", start: date(200)),
            event(id: "other", klantNaam: "Pietersen", start: date(300)),
        ]
        let groups = KlantGrouping.group(events)
        #expect(groups.map(\.naam) == ["Jansen", "Pietersen"])
        #expect(groups[0].events.map(\.id) == ["linked", "legacy"])
    }

    // MARK: - split (komend/eerder rond een vast "nu")

    @Test func splitDividesAroundAFixedNow() {
        let now = date(1000)
        let events = [
            event(id: "future", klantNaam: "Jansen", start: date(2000)),
            event(id: "past", klantNaam: "Jansen", start: date(500)),
        ]
        let (upcoming, past) = KlantGrouping.split(events, now: now)
        #expect(upcoming.map(\.id) == ["future"])
        #expect(past.map(\.id) == ["past"])
    }

    @Test func splitPutsEventStartingExactlyAtNowInUpcoming() {
        let now = date(1000)
        let events = [event(id: "onNow", klantNaam: "Jansen", start: now)]
        let (upcoming, past) = KlantGrouping.split(events, now: now)
        #expect(upcoming.map(\.id) == ["onNow"])
        #expect(past.isEmpty)
    }

    @Test func splitReturnsPastMostRecentFirst() {
        let now = date(1000)
        let events = [
            event(id: "oud", klantNaam: "Jansen", start: date(100)),
            event(id: "recent", klantNaam: "Jansen", start: date(500)),
        ]
        let (_, past) = KlantGrouping.split(events, now: now)
        #expect(past.map(\.id) == ["recent", "oud"])
    }
}
