import Testing
import Foundation
@testable import Bovexa

struct VandaagStatsTests {
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9, _ min: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h; comps.minute = min
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    private func makeEvent(start: Date, end: Date?) -> AgendaEvent {
        AgendaEvent(
            id: "ev", owner: "u1", calendar: nil, category: nil, title: "Test",
            start: start, end: end, allDay: false, recurrence: nil, location: nil, notes: nil,
            klantNaam: nil, assigneeStatus: [:], seriesId: nil, occurrenceDate: nil
        )
    }

    private func makeAllDay(start: Date, end: Date?) -> AgendaEvent {
        AgendaEvent(
            id: "afw", owner: "u1", calendar: nil, category: .afwezig, title: "Vakantie",
            start: start, end: end, allDay: true, recurrence: nil, location: nil, notes: nil,
            klantNaam: nil, assigneeStatus: [:], seriesId: nil, occurrenceDate: nil
        )
    }

    // Een hele-dag-blok (vakantie/ziek/vrij) is geen afspraak en telt ook niet
    // mee in de geplande uren — anders leest "4 afspraken · 27 uur" op een dag
    // met drie afspraken en één vakantiedag.

    @Test func allDayEventIsNotCountedAsAppointment() {
        let events = [
            makeEvent(start: date(2026, 7, 24, 9), end: date(2026, 7, 24, 10)),
            makeAllDay(start: date(2026, 7, 24, 0), end: nil),
        ]
        #expect(VandaagStats.timedCount(events) == 1)
        #expect(VandaagStats.allDayCount(events) == 1)
    }

    @Test func allDayEventWithEndDoesNotInflatePlannedHours() {
        let events = [
            makeEvent(start: date(2026, 7, 24, 9), end: date(2026, 7, 24, 10)),
            makeAllDay(start: date(2026, 7, 24, 0), end: date(2026, 7, 24, 23, 59)),
        ]
        #expect(VandaagStats.plannedHours(events) == 1.0)
    }

    @Test func awayNoteIsNilWithoutAllDayEvents() {
        let events = [makeEvent(start: date(2026, 7, 24, 9), end: date(2026, 7, 24, 10))]
        #expect(VandaagStats.awayNote(events) == nil)
    }

    @Test func awayNoteIsSingularForOneAndPluralForMore() {
        let one = [makeAllDay(start: date(2026, 7, 24, 0), end: nil)]
        #expect(VandaagStats.awayNote(one) == "1 afwezigheid")

        let two = [
            makeAllDay(start: date(2026, 7, 24, 0), end: nil),
            makeAllDay(start: date(2026, 7, 24, 0), end: nil),
        ]
        #expect(VandaagStats.awayNote(two) == "2 afwezigheden")
    }

    @Test func appointmentCountMatchesArrayCount() {
        let events = [
            makeEvent(start: date(2026, 7, 24, 9), end: date(2026, 7, 24, 10)),
            makeEvent(start: date(2026, 7, 24, 11), end: date(2026, 7, 24, 12)),
        ]
        #expect(VandaagStats.appointmentCount(events) == 2)
    }

    @Test func plannedHoursSumsDurationsInHours() {
        let events = [
            makeEvent(start: date(2026, 7, 24, 9), end: date(2026, 7, 24, 10, 30)), // 1.5u
            makeEvent(start: date(2026, 7, 24, 11), end: date(2026, 7, 24, 12)), // 1u
        ]
        #expect(VandaagStats.plannedHours(events) == 2.5)
    }

    @Test func plannedHoursIgnoresEventsWithoutEnd() {
        let events = [makeEvent(start: date(2026, 7, 24, 9), end: nil)]
        #expect(VandaagStats.plannedHours(events) == 0)
    }

    @Test func formatHoursShowsWholeNumberWithoutDecimal() {
        #expect(VandaagStats.formatHours(0) == "0 uur")
        #expect(VandaagStats.formatHours(2) == "2 uur")
    }

    /// 26 juli: uren en minuten in plaats van een decimaal uur — "9,8 uur" moest
    /// je eerst omrekenen voordat het iets zei.
    @Test func formatHoursShowsMinutesNotDecimals() {
        #expect(VandaagStats.formatHours(1.5) == "1 uur 30")
        #expect(VandaagStats.formatHours(9.75) == "9 uur 45")
    }

    @Test func weekBusyCountsGroupsMondayFirst() {
        // 2026-07-20 = maandag, 2026-07-24 = vrijdag, 2026-07-26 = zondag.
        let events = [
            makeEvent(start: date(2026, 7, 20, 9), end: date(2026, 7, 20, 10)), // ma
            makeEvent(start: date(2026, 7, 20, 14), end: date(2026, 7, 20, 15)), // ma (2e)
            makeEvent(start: date(2026, 7, 24, 9), end: date(2026, 7, 24, 10)), // vr
            makeEvent(start: date(2026, 7, 26, 9), end: date(2026, 7, 26, 10)), // zo
        ]
        let counts = VandaagStats.weekBusyCounts(events, referenceDate: date(2026, 7, 22))
        #expect(counts == [2, 0, 0, 0, 1, 0, 1])
    }

    @Test func weekBusyCountsIgnoresEventsOutsideTheWeek() {
        let events = [makeEvent(start: date(2026, 7, 13, 9), end: date(2026, 7, 13, 10))] // vorige week maandag
        let counts = VandaagStats.weekBusyCounts(events, referenceDate: date(2026, 7, 22))
        #expect(counts == [0, 0, 0, 0, 0, 0, 0])
    }
}
