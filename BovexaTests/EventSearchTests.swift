import Testing
import Foundation
@testable import Bovexa

/// Zoekscherm-filter — geport uit de resultaten-berekening in ~/Desktop/agenda-app/src/app/zoek.tsx.
struct EventSearchTests {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = 9
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    private func event(id: String, title: String = "", location: String? = nil, notes: String? = nil, start: Date) -> AgendaEvent {
        AgendaEvent(
            id: id, owner: "u1", calendar: nil, category: nil, title: title, start: start, end: nil,
            allDay: false, recurrence: nil, location: location, notes: notes, klantNaam: nil,
            assigneeStatus: [:], seriesId: nil, occurrenceDate: nil
        )
    }

    @Test func emptyQueryReturnsNoResults() {
        let events = [event(id: "a", title: "Tandarts", start: date(2026, 8, 3))]
        #expect(EventSearch.search(events, query: "  ").isEmpty)
    }

    @Test func matchesTitleCaseInsensitively() {
        let events = [event(id: "a", title: "Tandarts Jansen", start: date(2026, 8, 3))]
        #expect(EventSearch.search(events, query: "TANDARTS").map(\.id) == ["a"])
    }

    @Test func matchesLocationWhenTitleDoesNotMatch() {
        let events = [event(id: "a", title: "Afspraak", location: "Ziekenhuis Tiel", start: date(2026, 8, 3))]
        #expect(EventSearch.search(events, query: "tiel").map(\.id) == ["a"])
    }

    @Test func matchesNotesWhenTitleAndLocationDoNotMatch() {
        let events = [event(id: "a", title: "Afspraak", notes: "Offerte meenemen", start: date(2026, 8, 3))]
        #expect(EventSearch.search(events, query: "offerte").map(\.id) == ["a"])
    }

    @Test func noMatchReturnsEmpty() {
        let events = [event(id: "a", title: "Tandarts", start: date(2026, 8, 3))]
        #expect(EventSearch.search(events, query: "loodgieter").isEmpty)
    }

    @Test func resultsAreSortedNewestFirst() {
        let events = [
            event(id: "oud", title: "Tandarts oud", start: date(2026, 7, 1)),
            event(id: "nieuw", title: "Tandarts nieuw", start: date(2026, 8, 1)),
        ]
        #expect(EventSearch.search(events, query: "tandarts").map(\.id) == ["nieuw", "oud"])
    }
}
