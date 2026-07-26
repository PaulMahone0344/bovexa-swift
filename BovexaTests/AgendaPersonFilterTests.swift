import Testing
import Foundation
@testable import Bovexa

/// m10 plak 1: "de agenda van persoon P" is alles wat P bezit óf wat aan P is
/// toegewezen. Een afspraak die de baas aanmaakt en aan Daan toewijst hoort in
/// Daans dag, anders mist een medewerker precies zijn eigen werk.
struct AgendaPersonFilterTests {
    private func event(
        id: String = "e1", owner: String, assignee: [String] = [], isExternal: Bool = false
    ) -> AgendaEvent {
        AgendaEvent(
            id: id, owner: owner, calendar: nil, category: .work, title: "Klus",
            start: Date(timeIntervalSince1970: 1_784_000_000), end: nil, allDay: false,
            recurrence: nil, location: nil, notes: nil, klantNaam: nil,
            assigneeStatus: [:], seriesId: nil, occurrenceDate: nil,
            assignee: assignee, isExternal: isExternal
        )
    }

    @Test("Zonder filter komt alles door")
    func nilFilterPassesEverything() {
        let own = event(owner: "u1")
        let other = event(owner: "u2")
        let external = event(owner: "", isExternal: true)
        #expect(AgendaPersonFilter.matches(own, userId: nil))
        #expect(AgendaPersonFilter.matches(other, userId: nil))
        #expect(AgendaPersonFilter.matches(external, userId: nil))
    }

    @Test("Eigenaar matcht")
    func ownerMatches() {
        #expect(AgendaPersonFilter.matches(event(owner: "u2"), userId: "u2"))
    }

    @Test("Toegewezene matcht, ook als iemand anders de eigenaar is")
    func assigneeMatches() {
        let assigned = event(owner: "u1", assignee: ["u2", "u3"])
        #expect(AgendaPersonFilter.matches(assigned, userId: "u2"))
        #expect(AgendaPersonFilter.matches(assigned, userId: "u3"))
    }

    @Test("Iemand die er niets mee te maken heeft matcht niet")
    func unrelatedDoesNotMatch() {
        #expect(!AgendaPersonFilter.matches(event(owner: "u1", assignee: ["u2"]), userId: "u9"))
    }

    /// Externe afspraken komen van het toestel van de ingelogde gebruiker en
    /// hebben geen eigenaar; die horen nooit bij een collega.
    @Test("Externe afspraak matcht geen enkele persoon")
    func externalNeverMatchesAPerson() {
        let external = event(owner: "", isExternal: true)
        #expect(!AgendaPersonFilter.matches(external, userId: "u1"))
        #expect(!AgendaPersonFilter.matches(external, userId: "u2"))
    }

    @Test("Filteren van een lijst houdt de volgorde aan")
    func applyKeepsOrder() {
        let events = [
            event(id: "a", owner: "u1"),
            event(id: "b", owner: "u2"),
            event(id: "c", owner: "u1", assignee: ["u2"]),
        ]
        #expect(AgendaPersonFilter.apply(events, userId: "u2").map(\.id) == ["b", "c"])
        #expect(AgendaPersonFilter.apply(events, userId: nil).map(\.id) == ["a", "b", "c"])
    }
}
