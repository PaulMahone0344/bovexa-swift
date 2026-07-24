import Testing
import Foundation
@testable import Bovexa

struct ListViewGroupingTests {
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    private func makeEvent(id: String, start: Date, end: Date? = nil) -> AgendaEvent {
        AgendaEvent(
            id: id, owner: "u1", calendar: nil, category: nil, title: "Test \(id)",
            start: start, end: end, allDay: false, recurrence: nil, location: nil, notes: nil,
            klantNaam: nil, assigneeStatus: [:], seriesId: nil, occurrenceDate: nil
        )
    }

    @Test func groupsEventsByCalendarDayInChronologicalOrder() {
        let events = [
            makeEvent(id: "b", start: date(2026, 7, 25, 9)),
            makeEvent(id: "a", start: date(2026, 7, 24, 9)),
            makeEvent(id: "c", start: date(2026, 7, 25, 14)),
        ]
        let groups = ListViewGrouping.upcomingGroupedByDay(events, from: date(2026, 7, 24, 0))
        #expect(groups.count == 2)
        #expect(groups[0].events.map(\.id) == ["a"])
        #expect(groups[1].events.map(\.id) == ["b", "c"])
    }

    @Test func excludesEventsThatHaveAlreadyEnded() {
        let past = makeEvent(id: "past", start: date(2026, 7, 20, 9), end: date(2026, 7, 20, 10))
        let upcoming = makeEvent(id: "next", start: date(2026, 7, 26, 9))
        let groups = ListViewGrouping.upcomingGroupedByDay([past, upcoming], from: date(2026, 7, 24, 0))
        #expect(groups.count == 1)
        #expect(groups[0].events.map(\.id) == ["next"])
    }

    @Test func emptyInputProducesNoGroups() {
        let groups = ListViewGrouping.upcomingGroupedByDay([], from: date(2026, 7, 24, 0))
        #expect(groups.isEmpty)
    }

    @Test func groupIdsAreUniquePerDay() {
        let events = [
            makeEvent(id: "a", start: date(2026, 7, 24, 9)),
            makeEvent(id: "b", start: date(2026, 7, 25, 9)),
        ]
        let groups = ListViewGrouping.upcomingGroupedByDay(events, from: date(2026, 7, 24, 0))
        #expect(Set(groups.map(\.id)).count == groups.count)
    }
}
