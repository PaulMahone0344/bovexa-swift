import Testing
import Foundation
@testable import Bovexa

struct AbsenceLayoutTests {
    private func dayStart(_ y: Int = 2026, _ m: Int = 7, _ d: Int = 24) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = 0; comps.minute = 0
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    private func time(_ dayStart: Date, _ h: Int, _ min: Int = 0) -> Date {
        dayStart.addingTimeInterval(Double(h * 3600 + min * 60))
    }

    private func makeEvent(
        id: String = "ev1", owner: String = "u1", category: BovexaTheme.Category? = .afwezig,
        start: Date, end: Date? = nil, allDay: Bool = true
    ) -> AgendaEvent {
        AgendaEvent(
            id: id, owner: owner, calendar: nil, category: category, title: "Afwezig",
            start: start, end: end, allDay: allDay, recurrence: nil, location: nil, notes: nil,
            klantNaam: nil, assigneeStatus: [:], seriesId: nil, occurrenceDate: nil
        )
    }

    @Test func singleAllDayAbsenceGetsFullDayBand() {
        let start = dayStart()
        let event = makeEvent(start: start)
        let bands = AbsenceLayout.bands([event], dayStart: start)
        #expect(bands.count == 1)
        #expect(bands[0].columnCount == 1)
        #expect(bands[0].column == 0)
        #expect(bands[0].startMinutes == 0)
        #expect(bands[0].durationMinutes == 1440)
    }

    @Test func twoAllDayAbsencesSitSideBySideInDistinctColumns() {
        let start = dayStart()
        let a = makeEvent(id: "a", owner: "u1", start: start)
        let b = makeEvent(id: "b", owner: "u2", start: start)
        let bands = AbsenceLayout.bands([a, b], dayStart: start)
        #expect(bands.count == 2)
        #expect(bands.allSatisfy { $0.columnCount == 2 })
        #expect(Set(bands.map(\.column)) == [0, 1])
    }

    @Test func nonAfwezigAllDayEventProducesNoBand() {
        let start = dayStart()
        let event = makeEvent(category: .work, start: start)
        let bands = AbsenceLayout.bands([event], dayStart: start)
        #expect(bands.isEmpty)
    }

    @Test func regularTimedEventIsIgnoredByAbsenceLayout() {
        let start = dayStart()
        let event = makeEvent(category: .work, start: time(start, 9), end: time(start, 10), allDay: false)
        let bands = AbsenceLayout.bands([event], dayStart: start)
        #expect(bands.isEmpty)
    }

    @Test func partialDayAbsenceIsNotAlsoDrawnAsTimedBlock() {
        let start = dayStart()
        let absence = makeEvent(id: "vrij", start: time(start, 13), end: time(start, 17), allDay: false)
        let meeting = makeEvent(id: "afspraak", category: .work, start: time(start, 9), end: time(start, 10), allDay: false)
        let timed = AbsenceLayout.timedNonAbsence([absence, meeting])
        #expect(timed.map(\.id) == ["afspraak"])
        #expect(AbsenceLayout.bands([absence, meeting], dayStart: start).map(\.event.id) == ["vrij"])
    }

    @Test func allDayEventsAreNeverTimedBlocks() {
        let start = dayStart()
        let absence = makeEvent(id: "vrij", start: start)
        let holiday = makeEvent(id: "feestdag", category: .social, start: start)
        #expect(AbsenceLayout.timedNonAbsence([absence, holiday]).isEmpty)
    }

    @Test func partialDayAbsenceUsesEventRangeInsteadOfFullDay() {
        let start = dayStart()
        let event = makeEvent(start: time(start, 13), end: time(start, 17), allDay: false)
        let bands = AbsenceLayout.bands([event], dayStart: start)
        #expect(bands.count == 1)
        #expect(bands[0].startMinutes == 13 * 60)
        #expect(bands[0].durationMinutes == 4 * 60)
    }
}
