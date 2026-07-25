import Testing
import Foundation
@testable import Bovexa

struct EventDetailFormattingTests {
    private func date(_ h: Int, _ min: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 24; comps.hour = h; comps.minute = min
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    private func makeEvent(start: Date, end: Date?, allDay: Bool) -> AgendaEvent {
        AgendaEvent(
            id: "ev", owner: "u1", calendar: nil, category: nil, title: "Test",
            start: start, end: end, allDay: allDay, recurrence: nil, location: nil, notes: nil,
            klantNaam: nil, assigneeStatus: [:], seriesId: nil, occurrenceDate: nil
        )
    }

    @Test func allDayEventShowsHeleDag() {
        let event = makeEvent(start: date(0), end: nil, allDay: true)
        #expect(EventHelpers.detailTimeText(event) == "Hele dag")
    }

    @Test func timedEventWithEndShowsStartAndDuration() {
        let event = makeEvent(start: date(9), end: date(10, 30), allDay: false)
        #expect(EventHelpers.detailTimeText(event) == "09:00 · 1 uur 30 min")
    }

    @Test func timedEventWithoutEndShowsOnlyStart() {
        let event = makeEvent(start: date(9), end: nil, allDay: false)
        #expect(EventHelpers.detailTimeText(event) == "09:00")
    }

    // Rij-weergave (tijdlijn Vandaag, DaySheet, lijst, zoekresultaat). Het
    // Afwezig-scherm schrijft hele-dag-events weg; die toonden hier "00:00".

    @Test func allDayEventShowsHeleDagInRow() {
        let event = makeEvent(start: date(0), end: nil, allDay: true)
        #expect(EventHelpers.rowTimeText(event) == "Hele dag")
    }

    @Test func timedEventShowsClockTimeInRow() {
        let event = makeEvent(start: date(9, 30), end: date(10), allDay: false)
        #expect(EventHelpers.rowTimeText(event) == "09:30")
    }

    @Test func allDayEventHasNoDurationLabel() {
        let event = makeEvent(start: date(0), end: date(23, 59), allDay: true)
        #expect(EventHelpers.rowDurationLabel(event) == "")
    }

    @Test func timedEventKeepsDurationLabel() {
        let event = makeEvent(start: date(9), end: date(10), allDay: false)
        #expect(EventHelpers.rowDurationLabel(event) == "1 uur")
    }
}
