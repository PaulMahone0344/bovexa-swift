import Testing
import Foundation
@testable import Bovexa

struct DayViewLayoutTests {
    private func date(_ h: Int, _ min: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 24; comps.hour = h; comps.minute = min
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    private func makeEvent(id: String, start: Date, end: Date?, allDay: Bool = false) -> AgendaEvent {
        AgendaEvent(
            id: id, owner: "u1", calendar: nil, category: nil, title: "Test \(id)",
            start: start, end: end, allDay: allDay, recurrence: nil, location: nil, notes: nil,
            klantNaam: nil, assigneeStatus: [:], seriesId: nil, occurrenceDate: nil
        )
    }

    @Test func nonOverlappingEventsEachGetTheirOwnFullWidthColumn() {
        let events = [
            makeEvent(id: "a", start: date(9), end: date(10)),
            makeEvent(id: "b", start: date(10), end: date(11)),
        ]
        let result = DayViewLayout.layout(events)
        #expect(result.count == 2)
        #expect(result.allSatisfy { $0.columnCount == 1 && $0.column == 0 })
    }

    @Test func overlappingEventsSplitIntoSideBySideColumns() {
        let events = [
            makeEvent(id: "a", start: date(9), end: date(10)),
            makeEvent(id: "b", start: date(9, 30), end: date(10, 30)),
        ]
        let result = DayViewLayout.layout(events)
        let a = result.first { $0.event.id == "a" }!
        let b = result.first { $0.event.id == "b" }!
        #expect(a.columnCount == 2)
        #expect(b.columnCount == 2)
        #expect(a.column != b.column)
    }

    @Test func thirdEventReusesFreedColumnWhenItFitsAfterAnEarlierOneEnds() {
        // A 9-10 (kolom 0), B 9:30-10:30 (kolom 1, overlapt A), C 10:15-11:00
        // (kolom 0 is dan weer vrij: A eindigde om 10:00).
        let events = [
            makeEvent(id: "a", start: date(9), end: date(10)),
            makeEvent(id: "b", start: date(9, 30), end: date(10, 30)),
            makeEvent(id: "c", start: date(10, 15), end: date(11)),
        ]
        let result = DayViewLayout.layout(events)
        let a = result.first { $0.event.id == "a" }!
        let b = result.first { $0.event.id == "b" }!
        let c = result.first { $0.event.id == "c" }!
        #expect(a.column == 0)
        #expect(b.column == 1)
        #expect(c.column == 0)
        #expect([a, b, c].allSatisfy { $0.columnCount == 2 })
    }

    @Test func backToBackEventsDoNotOverlap() {
        // eind == start telt niet als overlap.
        let events = [
            makeEvent(id: "a", start: date(9), end: date(10)),
            makeEvent(id: "b", start: date(10), end: date(11)),
        ]
        let result = DayViewLayout.layout(events)
        #expect(result.allSatisfy { $0.columnCount == 1 })
    }

    @Test func allDayEventsAreExcludedFromTheHourGridLayout() {
        let events = [
            makeEvent(id: "a", start: date(0), end: nil, allDay: true),
            makeEvent(id: "b", start: date(9), end: date(10)),
        ]
        let result = DayViewLayout.layout(events)
        #expect(result.map(\.event.id) == ["b"])
    }

    @Test func eventsWithoutEndTreatedAsZeroDurationDoNotForceOverlap() {
        let events = [
            makeEvent(id: "a", start: date(9), end: nil),
            makeEvent(id: "b", start: date(9, 30), end: date(10)),
        ]
        let result = DayViewLayout.layout(events)
        #expect(result.allSatisfy { $0.columnCount == 1 })
    }
}
