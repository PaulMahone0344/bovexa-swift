import Testing
import Foundation
@testable import Bovexa

/// m10 plak 1: "de agenda van persoon P" is alles wat P bezit óf wat aan P is
/// toegewezen. Een afspraak die de baas aanmaakt en aan Daan toewijst hoort in
/// Daans dag, anders mist een medewerker precies zijn eigen werk.
///
/// Omgedraaid op 26 juli: je vinkt mensen aan in plaats van er één te kiezen, en
/// je eigen agenda staat altijd aan.
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

    @Test("Alleen jezelf aangevinkt laat andermans afspraak weg")
    func onlyOwnAgendaHidesColleagues() {
        #expect(AgendaPersonFilter.matches(event(owner: "u1"), userIds: ["u1"]))
        #expect(!AgendaPersonFilter.matches(event(owner: "u2"), userIds: ["u1"]))
    }

    @Test("Een collega erbij vinken laat zijn afspraak zien")
    func addingAColleagueShowsTheirEvents() {
        #expect(AgendaPersonFilter.matches(event(owner: "u2"), userIds: ["u1", "u2"]))
    }

    @Test("Toegewezene matcht, ook als iemand anders de eigenaar is")
    func assigneeMatches() {
        let assigned = event(owner: "u1", assignee: ["u2", "u3"])
        #expect(AgendaPersonFilter.matches(assigned, userIds: ["u2"]))
        #expect(AgendaPersonFilter.matches(assigned, userIds: ["u3"]))
    }

    @Test("Iemand die er niets mee te maken heeft matcht niet")
    func unrelatedDoesNotMatch() {
        #expect(!AgendaPersonFilter.matches(event(owner: "u1", assignee: ["u2"]), userIds: ["u9"]))
    }

    /// Externe afspraken komen van het toestel van de ingelogde gebruiker en hebben
    /// geen eigenaar. Ze horen bij niemand in het bedrijf, maar wél bij jou — en
    /// jouw agenda staat altijd aan, dus ze blijven staan.
    @Test("Externe afspraak blijft staan, wie je ook aanvinkt")
    func externalAlwaysVisible() {
        let external = event(owner: "", isExternal: true)
        #expect(AgendaPersonFilter.matches(external, userIds: ["u1"]))
        #expect(AgendaPersonFilter.matches(external, userIds: ["u1", "u2"]))
    }

    @Test("Lege selectie toont alles in plaats van niets")
    func emptySelectionFallsBackToEverything() {
        #expect(AgendaPersonFilter.matches(event(owner: "u2"), userIds: []))
    }

    @Test("Filteren van een lijst houdt de volgorde aan")
    func applyKeepsOrder() {
        let events = [
            event(id: "a", owner: "u1"),
            event(id: "b", owner: "u2"),
            event(id: "c", owner: "u1", assignee: ["u2"]),
        ]
        #expect(AgendaPersonFilter.apply(events, userIds: ["u2"]).map(\.id) == ["b", "c"])
        #expect(AgendaPersonFilter.apply(events, userIds: ["u1", "u2"]).map(\.id) == ["a", "b", "c"])
        #expect(AgendaPersonFilter.apply(events, userIds: ["u1"]).map(\.id) == ["a", "c"])
    }
}
