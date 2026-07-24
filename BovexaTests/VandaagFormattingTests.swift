import Testing
import Foundation
@testable import Bovexa

struct VandaagFormattingTests {
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
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

    @Test func durationLabelUnderAnHourShowsMinutesOnly() {
        let event = makeEvent(start: date(2026, 7, 24, 9, 0), end: date(2026, 7, 24, 9, 30))
        #expect(EventHelpers.durationLabel(event) == "30 min")
    }

    @Test func durationLabelExactHourShowsHoursOnly() {
        let event = makeEvent(start: date(2026, 7, 24, 9, 0), end: date(2026, 7, 24, 10, 0))
        #expect(EventHelpers.durationLabel(event) == "1 uur")
    }

    @Test func durationLabelWithRemainderShowsHoursAndMinutes() {
        let event = makeEvent(start: date(2026, 7, 24, 9, 0), end: date(2026, 7, 24, 10, 30))
        #expect(EventHelpers.durationLabel(event) == "1 uur 30 min")
    }

    @Test func durationLabelWithoutEndIsEmpty() {
        let event = makeEvent(start: date(2026, 7, 24, 9, 0), end: nil)
        #expect(EventHelpers.durationLabel(event) == "")
    }
}
