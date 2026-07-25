import Testing
import Foundation
@testable import Bovexa

/// Mini-maand-cellen voor het jaaroverzicht — geport uit monthCells() in
/// ~/Desktop/agenda-app/src/app/kalender.tsx. Maand is 0-based (jan=0), zoals JS.
struct YearOverviewGridTests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test func cellCountIsAlwaysAMultipleOfSeven() {
        for month in 0...11 {
            let cells = YearOverviewGrid.monthCells(year: 2026, month: month, calendar: calendar)
            #expect(cells.count % 7 == 0, "maand \(month) gaf \(cells.count) cellen")
        }
    }

    @Test func containsExactlyTheDaysInTheMonthInOrder() {
        let cells = YearOverviewGrid.monthCells(year: 2026, month: 1, calendar: calendar) // februari 2026 = 28 dagen
        let days = cells.compactMap { $0 }
        #expect(days == Array(1...28))
    }

    @Test func firstDayOffsetMatchesRealWeekday() {
        // maandag = 0 offset; de eerste niet-nil cel moet op de juiste weekdag-index staan.
        var comps = DateComponents(); comps.year = 2026; comps.month = 2; comps.day = 1 // 1 = jan → month param is 1-based hier
        let firstOfMonth = calendar.date(from: comps)!
        let weekday = calendar.component(.weekday, from: firstOfMonth) // 1 = zondag
        let expectedOffset = (weekday + 5) % 7

        let cells = YearOverviewGrid.monthCells(year: 2026, month: 1, calendar: calendar)
        let firstNonNilIndex = cells.firstIndex { $0 != nil }!
        #expect(firstNonNilIndex == expectedOffset)
    }

    @Test func decemberHasThirtyOneDays() {
        let cells = YearOverviewGrid.monthCells(year: 2026, month: 11, calendar: calendar)
        #expect(cells.compactMap { $0 }.count == 31)
    }
}

struct EventDaySetTests {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = 9
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    private func event(id: String, start: Date) -> AgendaEvent {
        AgendaEvent(
            id: id, owner: "u1", calendar: nil, category: nil, title: "T", start: start, end: nil,
            allDay: false, recurrence: nil, location: nil, notes: nil, klantNaam: nil,
            assigneeStatus: [:], seriesId: nil, occurrenceDate: nil
        )
    }

    @Test func buildProducesZeroBasedMonthKeys() {
        let events = [event(id: "a", start: date(2026, 8, 3))] // augustus
        let keys = EventDaySet.build(from: events)
        #expect(keys.contains(EventDayKey(year: 2026, month: 7, day: 3))) // 0-based: augustus = 7
    }

    @Test func multipleEventsOnSameDayProduceOneKey() {
        let events = [event(id: "a", start: date(2026, 8, 3)), event(id: "b", start: date(2026, 8, 3))]
        #expect(EventDaySet.build(from: events).count == 1)
    }

    @Test func dayCountFiltersToYearAndMonth() {
        let events = [
            event(id: "a", start: date(2026, 8, 3)),
            event(id: "b", start: date(2026, 8, 10)),
            event(id: "c", start: date(2026, 9, 1)),
            event(id: "d", start: date(2025, 8, 5)),
        ]
        let keys = EventDaySet.build(from: events)
        #expect(keys.filter { $0.year == 2026 && $0.month == 7 }.count == 2)
    }
}
