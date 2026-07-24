import Testing
import Foundation
@testable import Bovexa

struct MonthDensityTests {
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    private func makeEvent(id: String, start: Date) -> AgendaEvent {
        AgendaEvent(
            id: id, owner: "u1", calendar: nil, category: nil, title: "Test \(id)",
            start: start, end: nil, allDay: false, recurrence: nil, location: nil, notes: nil,
            klantNaam: nil, assigneeStatus: [:], seriesId: nil, occurrenceDate: nil
        )
    }

    @Test func returnsAllEventsWhenUnderTheMax() {
        let events = (1...2).map { makeEvent(id: "\($0)", start: date(2026, 7, 24, $0)) }
        let result = MonthDensity.titleChips(for: events, max: 3)
        #expect(result.shown.count == 2)
        #expect(result.overflow == 0)
    }

    @Test func truncatesAndCountsOverflowBeyondTheMax() {
        let events = (1...5).map { makeEvent(id: "\($0)", start: date(2026, 7, 24, $0)) }
        let result = MonthDensity.titleChips(for: events, max: 3)
        #expect(result.shown.count == 3)
        #expect(result.overflow == 2)
    }

    @Test func exactlyAtMaxHasNoOverflow() {
        let events = (1...3).map { makeEvent(id: "\($0)", start: date(2026, 7, 24, $0)) }
        let result = MonthDensity.titleChips(for: events, max: 3)
        #expect(result.shown.count == 3)
        #expect(result.overflow == 0)
    }
}
