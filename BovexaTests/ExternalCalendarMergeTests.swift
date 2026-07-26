import Testing
import Foundation
@testable import Bovexa

/// ExternalCalendarMerge — m9 plak 4. Eigen events blijven ongemoeid, externe events
/// komen erbij en de sortering per starttijd klopt (valkuil G: alleen de marge rond de
/// zichtbare periode wordt opgevraagd, niet de hele agenda).
struct ExternalCalendarMergeTests {
    private func ownEvent(id: String, start: Date) -> AgendaEvent {
        AgendaEvent(
            id: id, owner: "me", calendar: nil, category: nil, title: "Eigen", start: start, end: nil,
            allDay: false, recurrence: nil, location: nil, notes: nil, klantNaam: nil,
            assigneeStatus: [:], seriesId: nil, occurrenceDate: nil
        )
    }

    private func externalEvent(id: String, start: Date) -> DeviceCalendarEvent {
        DeviceCalendarEvent(id: id, calendarId: "cal1", calendarTitle: "Werk", title: "Extern", startDate: start, endDate: start.addingTimeInterval(3600), isAllDay: false, location: nil, notes: nil)
    }

    @Test func noExternalEventsLeavesOwnEventsUnchanged() {
        let own = [ownEvent(id: "a", start: Date(timeIntervalSince1970: 1_753_000_000))]
        let merged = ExternalCalendarMerge.merge(own, external: [])
        #expect(merged.map(\.id) == ["a"])
    }

    @Test func externalEventsAreAddedWithoutTouchingOwnEvents() {
        let own = [ownEvent(id: "a", start: Date(timeIntervalSince1970: 1_753_000_000))]
        let external = [externalEvent(id: "ev1", start: Date(timeIntervalSince1970: 1_753_100_000))]
        let merged = ExternalCalendarMerge.merge(own, external: external)
        #expect(merged.count == 2)
        #expect(merged.contains { $0.id == "a" && $0.isExternal == false })
        #expect(merged.contains { $0.isExternal == true })
    }

    @Test func mergedResultIsSortedByStartTime() {
        let own = [ownEvent(id: "a", start: Date(timeIntervalSince1970: 1_753_200_000))]
        let external = [externalEvent(id: "ev1", start: Date(timeIntervalSince1970: 1_753_000_000))]
        let merged = ExternalCalendarMerge.merge(own, external: external)
        #expect(merged.first?.id.hasPrefix("ext:") == true)
        #expect(merged.last?.id == "a")
    }

    @Test func fetchIntervalHasAMonthMarginBeforeAndAfter() {
        let anchor = Date(timeIntervalSince1970: 1_753_000_000)
        let interval = ExternalCalendarMerge.fetchInterval(around: anchor)
        #expect(interval.start < anchor)
        #expect(interval.end > anchor)
        let calendar = Calendar.current
        #expect(calendar.dateComponents([.month], from: interval.start, to: anchor).month == 1)
        #expect(calendar.dateComponents([.month], from: anchor, to: interval.end).month == 1)
    }
}
