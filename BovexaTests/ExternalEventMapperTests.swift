import Testing
import Foundation
@testable import Bovexa

/// ExternalEventMapper — m9 plak 2. Synthetische id (valkuil A) zodat je overal kunt
/// zien dat het om een extern event gaat, en isExternal staat aan (valkuil B).
struct ExternalEventMapperTests {
    private func event(
        id: String = "ev1", calendarId: String = "cal1", calendarTitle: String = "Werk",
        title: String? = "Overleg", start: Date = Date(timeIntervalSince1970: 1_753_000_000),
        end: Date = Date(timeIntervalSince1970: 1_753_003_600), allDay: Bool = false,
        location: String? = nil, notes: String? = nil
    ) -> DeviceCalendarEvent {
        DeviceCalendarEvent(id: id, calendarId: calendarId, calendarTitle: calendarTitle, title: title, startDate: start, endDate: end, isAllDay: allDay, location: location, notes: notes)
    }

    @Test func mapsToExternalAgendaEventWithSyntheticId() {
        let mapped = ExternalEventMapper.map(event())
        #expect(mapped.id.hasPrefix("ext:cal1:ev1:"))
        #expect(mapped.isExternal == true)
        #expect(mapped.title == "Overleg")
    }

    @Test func allDayEventComesBackAsAllDay() {
        let mapped = ExternalEventMapper.map(event(allDay: true))
        #expect(mapped.allDay == true)
    }

    @Test func timedEventKeepsItsTimes() {
        let start = Date(timeIntervalSince1970: 1_753_000_000)
        let end = Date(timeIntervalSince1970: 1_753_003_600)
        let mapped = ExternalEventMapper.map(event(start: start, end: end, allDay: false))
        #expect(mapped.allDay == false)
        #expect(mapped.start == start)
        #expect(mapped.end == end)
    }

    @Test func twoOccurrencesOfTheSameRecurrenceGetDifferentIds() {
        let first = ExternalEventMapper.map(event(id: "ev1", start: Date(timeIntervalSince1970: 1_753_000_000), end: Date(timeIntervalSince1970: 1_753_003_600)))
        let second = ExternalEventMapper.map(event(id: "ev1", start: Date(timeIntervalSince1970: 1_753_600_000), end: Date(timeIntervalSince1970: 1_753_603_600)))
        #expect(first.id != second.id)
    }

    @Test func titlelessEventGetsAReadableFallback() {
        let mapped = ExternalEventMapper.map(event(title: nil))
        #expect(mapped.title == "Afspraak")
    }

    @Test func usesCalendarTitleAsSourceInNotes() {
        let mapped = ExternalEventMapper.map(event(calendarTitle: "Verjaardagen"))
        #expect(mapped.calendar == "Verjaardagen")
    }

    @Test func carriesLocationThrough() {
        let mapped = ExternalEventMapper.map(event(location: "Tiel"))
        #expect(mapped.location == "Tiel")
    }

    @Test func hasNoCategoryLabelOrAssignment() {
        let mapped = ExternalEventMapper.map(event())
        #expect(mapped.category == nil)
        #expect(mapped.label == nil)
        #expect(mapped.assignee.isEmpty)
    }
}
