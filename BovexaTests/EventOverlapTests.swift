import Testing
import Foundation
@testable import Bovexa

struct EventOverlapTests {
    private func date(_ h: Int, _ min: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 8; comps.day = 3; comps.hour = h; comps.minute = min
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    private func makeEvent(id: String, start: Date, end: Date?, seriesId: String? = nil) -> AgendaEvent {
        AgendaEvent(
            id: id, owner: "u1", calendar: nil, category: nil, title: "Bestaand",
            start: start, end: end, allDay: false, recurrence: nil, location: nil, notes: nil,
            klantNaam: nil, assigneeStatus: [:], seriesId: seriesId, occurrenceDate: nil
        )
    }

    @Test func returnsOverlappingEvent() {
        let existing = makeEvent(id: "a", start: date(9), end: date(10))
        let hit = EventOverlap.findOverlap(in: [existing], start: date(9, 30), end: date(10, 30))
        #expect(hit?.id == "a")
    }

    @Test func adjacentEventsDoNotOverlap() {
        // Nieuw begin == bestaand einde: aansluitend, geen overlap (valkuil-randgeval).
        let existing = makeEvent(id: "a", start: date(9), end: date(10))
        let hit = EventOverlap.findOverlap(in: [existing], start: date(10), end: date(11))
        #expect(hit == nil)
    }

    @Test func adjacentBeforeDoesNotOverlap() {
        let existing = makeEvent(id: "a", start: date(9), end: date(10))
        let hit = EventOverlap.findOverlap(in: [existing], start: date(8), end: date(9))
        #expect(hit == nil)
    }

    @Test func nonOverlappingEventsReturnNil() {
        let existing = makeEvent(id: "a", start: date(9), end: date(10))
        let hit = EventOverlap.findOverlap(in: [existing], start: date(14), end: date(15))
        #expect(hit == nil)
    }

    @Test func excludeIdSkipsSelfDuringEdit() {
        let existing = makeEvent(id: "a", start: date(9), end: date(10))
        let hit = EventOverlap.findOverlap(in: [existing], start: date(9), end: date(10), excludeId: "a")
        #expect(hit == nil)
    }

    @Test func excludeIdMatchesRealRecordIdForExpandedOccurrence() {
        // Uitgeklapte occurrence heeft synthetisch id "recordId:datum" — excludeId is het echte record-id.
        let occurrence = makeEvent(id: "rec1:2026-08-03", start: date(9), end: date(10), seriesId: "rec1")
        let hit = EventOverlap.findOverlap(in: [occurrence], start: date(9), end: date(10), excludeId: "rec1")
        #expect(hit == nil)
    }

    @Test func eventWithoutEndTreatedAsZeroDuration() {
        // Zonder end telt het bestaande moment zelf als [start, start) — een nieuw
        // bereik dat er precies op begint (9-10) is aansluitend, geen overlap; een
        // bereik dat het bestaande moment omvat (8:30-9:30) is dat wel.
        let existing = makeEvent(id: "a", start: date(9), end: nil)
        let adjacent = EventOverlap.findOverlap(in: [existing], start: date(9), end: date(10))
        #expect(adjacent == nil)
        let straddling = EventOverlap.findOverlap(in: [existing], start: date(8, 30), end: date(9, 30))
        #expect(straddling?.id == "a")
    }
}
