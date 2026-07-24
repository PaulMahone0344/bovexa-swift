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

    @Test func formatHoursShowsDutchCommaForFraction() {
        #expect(VandaagStats.formatHours(1.5) == "1,5 uur")
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
