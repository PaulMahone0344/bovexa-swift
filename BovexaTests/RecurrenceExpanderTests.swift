import Testing
import Foundation
@testable import Bovexa

struct RecurrenceExpanderTests {
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9, _ min: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h; comps.minute = min
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    private func makeEvent(
        id: String = "ev1", start: Date, end: Date? = nil, recurrence: String? = nil
    ) -> AgendaEvent {
        AgendaEvent(
            id: id, owner: "u1", calendar: nil, category: nil, title: "Test",
            start: start, end: end, allDay: false, recurrence: recurrence,
            location: nil, notes: nil, klantNaam: nil, assigneeStatus: [:],
            seriesId: nil, occurrenceDate: nil
        )
    }

    @Test func nonRecurringEventPassesThroughUnchanged() {
        let event = makeEvent(start: date(2026, 7, 24))
        let result = RecurrenceExpander.expand([event])
        #expect(result.count == 1)
        #expect(result[0].id == "ev1")
        #expect(result[0].seriesId == nil)
    }

    @Test func emptyRecurrenceStringPassesThroughUnchanged() {
        let event = makeEvent(start: date(2026, 7, 24), recurrence: "")
        let result = RecurrenceExpander.expand([event])
        #expect(result.count == 1)
    }

    @Test func weeklyByDayWithUntilExpandsInclusiveRange() {
        // 2026-07-20 = maandag. FREQ=WEEKLY;BYDAY=MO,FR;UNTIL=20260731 (vrijdag) →
        // ma20, vr24, ma27, vr31 = 4 bezettingen, UNTIL-dag zelf meegeteld.
        let start = date(2026, 7, 20, 9, 30)
        let event = makeEvent(start: start, end: date(2026, 7, 20, 10, 0), recurrence: "FREQ=WEEKLY;BYDAY=MO,FR;UNTIL=20260731")
        let result = RecurrenceExpander.expand([event])

        #expect(result.count == 4)
        #expect(result.map(\.id) == ["ev1:2026-07-20", "ev1:2026-07-24", "ev1:2026-07-27", "ev1:2026-07-31"])
        #expect(result.allSatisfy { $0.seriesId == "ev1" })
        #expect(result.map(\.occurrenceDate) == ["2026-07-20", "2026-07-24", "2026-07-27", "2026-07-31"])

        let calendar = Calendar(identifier: .gregorian)
        for occurrence in result {
            let comps = calendar.dateComponents([.hour, .minute], from: occurrence.start)
            #expect(comps.hour == 9)
            #expect(comps.minute == 30)
            // duur (30 min) blijft behouden per bezetting.
            #expect(occurrence.end!.timeIntervalSince(occurrence.start) == 1800)
        }
    }

    @Test func weeklyWithoutUntilCapsAtThreeHundredSixtyFiveDayHorizon() {
        // Geen UNTIL → horizon = start + 365 dagen. Alleen maandagen: 53 bezettingen,
        // laatste op 2027-07-19 (2027-07-20 zelf is een dinsdag, buiten de laatste week).
        let event = makeEvent(start: date(2026, 7, 20), recurrence: "FREQ=WEEKLY;BYDAY=MO")
        let result = RecurrenceExpander.expand([event])

        #expect(result.count == 53)
        #expect(result.last?.occurrenceDate == "2027-07-19")
        #expect(result.allSatisfy { ($0.occurrenceDate ?? "") <= "2027-07-20" })
    }

    @Test func exceedingFiveHundredOccurrencesGetsCapped() {
        // Elke dag van de week, UNTIL ver in de toekomst → zonder cap duizenden
        // bezettingen. Cap op 500, laatste = start + 499 dagen (2027-12-01).
        let event = makeEvent(
            start: date(2026, 7, 20),
            recurrence: "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR,SA,SU;UNTIL=20360720"
        )
        let result = RecurrenceExpander.expand([event])

        #expect(result.count == 500)
        #expect(result.last?.occurrenceDate == "2027-12-01")
    }

    @Test func nonWeeklyFrequencyPassesThroughUnchanged() {
        let event = makeEvent(start: date(2026, 7, 24), recurrence: "FREQ=DAILY")
        let result = RecurrenceExpander.expand([event])
        #expect(result.count == 1)
        #expect(result[0].id == "ev1")
    }

    @Test func missingByDayPassesThroughUnchanged() {
        let event = makeEvent(start: date(2026, 7, 24), recurrence: "FREQ=WEEKLY")
        let result = RecurrenceExpander.expand([event])
        #expect(result.count == 1)
    }
}
