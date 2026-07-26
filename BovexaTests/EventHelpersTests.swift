import Testing
import Foundation
import SwiftUI
@testable import Bovexa

struct EventHelpersTests {
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9, _ min: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h; comps.minute = min
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    private func makeEvent(
        id: String = "ev1", owner: String = "u1", calendar: String? = nil,
        category: BovexaTheme.Category? = nil, start: Date, end: Date? = nil, label: String? = nil,
        isExternal: Bool = false
    ) -> AgendaEvent {
        AgendaEvent(
            id: id, owner: owner, calendar: calendar, category: category, title: "Test",
            start: start, end: end, allDay: false, recurrence: nil, location: nil, notes: nil,
            klantNaam: nil, assigneeStatus: [:], seriesId: nil, occurrenceDate: nil, label: label,
            isExternal: isExternal
        )
    }

    @Test func fmtTimeFormatsHoursAndMinutes() {
        #expect(EventHelpers.fmtTime(date(2026, 7, 24, 9, 5)) == "09:05")
        #expect(EventHelpers.fmtTime(nil) == "")
    }

    @Test func durationMinComputesMinutesBetweenStartAndEnd() {
        let event = makeEvent(start: date(2026, 7, 24, 9, 0), end: date(2026, 7, 24, 10, 30))
        #expect(EventHelpers.durationMin(event) == 90)
    }

    @Test func durationMinIsNilWithoutEnd() {
        let event = makeEvent(start: date(2026, 7, 24, 9, 0))
        #expect(EventHelpers.durationMin(event) == nil)
    }

    @Test func eventsOnDayFiltersToSameCalendarDay() {
        let onDay = makeEvent(id: "a", start: date(2026, 7, 24, 8, 0))
        let otherDay = makeEvent(id: "b", start: date(2026, 7, 25, 8, 0))
        let result = EventHelpers.eventsOnDay([onDay, otherDay], day: date(2026, 7, 24, 0, 0))
        #expect(result.map(\.id) == ["a"])
    }

    @Test func nextUpcomingPicksEarliestEventThatHasNotEndedYet() {
        let now = date(2026, 7, 24, 12, 0)
        let past = makeEvent(id: "past", start: date(2026, 7, 24, 9, 0), end: date(2026, 7, 24, 10, 0))
        let soon = makeEvent(id: "soon", start: date(2026, 7, 24, 13, 0))
        let later = makeEvent(id: "later", start: date(2026, 7, 24, 15, 0))
        let result = EventHelpers.nextUpcoming([later, past, soon], now: now)
        #expect(result?.id == "soon")
    }

    @Test func nextUpcomingReturnsNilWhenEverythingHasEnded() {
        let now = date(2026, 7, 24, 12, 0)
        let past = makeEvent(start: date(2026, 7, 24, 9, 0), end: date(2026, 7, 24, 10, 0))
        #expect(EventHelpers.nextUpcoming([past], now: now) == nil)
    }

    @Test func longDayFormatsDutchWeekdayAndMonth() {
        // 2026-07-24 = vrijdag.
        #expect(EventHelpers.longDay(date(2026, 7, 24)) == "Vrijdag 24 juli")
    }

    @Test func eventColorPrefersCategoryOverCalendarFallback() {
        let categorized = makeEvent(category: .social, start: date(2026, 7, 24))
        #expect(EventHelpers.eventColor(categorized) == BovexaTheme.categoryColor(for: .social))
    }

    @Test func eventColorFallsBackToPrivateOrTealByCalendar() {
        let privateEvent = makeEvent(calendar: "private", start: date(2026, 7, 24))
        let workEvent = makeEvent(calendar: "work", start: date(2026, 7, 24))
        #expect(EventHelpers.eventColor(privateEvent) == BovexaTheme.Colors.categoryBlue)
        #expect(EventHelpers.eventColor(workEvent) == BovexaTheme.Colors.blue)
    }

    // MARK: - eventColor met label (m7, valkuil C)

    @Test func eventColorPrefersLabelColorOverCategory() {
        let store = LabelStore()
        store.prime(labels: [AgendaLabel(id: "l1", org: "org1", naam: "VSB", kleur: "#E08A3C", volgorde: 0)])
        let event = makeEvent(category: .social, start: date(2026, 7, 24), label: "l1")
        #expect(EventHelpers.eventColor(event, labelStore: store) == Color(hex: "#E08A3C"))
    }

    @Test func eventColorWithoutLabelIsUnchanged() {
        let event = makeEvent(category: .social, start: date(2026, 7, 24))
        let store = LabelStore()
        #expect(EventHelpers.eventColor(event, labelStore: store) == BovexaTheme.categoryColor(for: .social))
    }

    @Test func eventColorWithUnknownLabelFallsBackToCategory() {
        let store = LabelStore()
        let event = makeEvent(category: .social, start: date(2026, 7, 24), label: "verwijderd")
        #expect(EventHelpers.eventColor(event, labelStore: store) == BovexaTheme.categoryColor(for: .social))
    }

    // MARK: - eventColor voor externe events (m9 plak 4, valkuil D)

    @Test func eventColorIsNeutralForExternalEventsEvenWithLabelOrCategory() {
        let store = LabelStore()
        store.prime(labels: [AgendaLabel(id: "l1", org: "org1", naam: "VSB", kleur: "#E08A3C", volgorde: 0)])
        let event = makeEvent(category: .social, start: date(2026, 7, 24), label: "l1", isExternal: true)
        #expect(EventHelpers.eventColor(event, labelStore: store) == BovexaTheme.Colors.muted)
    }

    @Test func eventColorWithNilLabelStoreIsUnchanged() {
        let event = makeEvent(category: .social, start: date(2026, 7, 24), label: "l1")
        #expect(EventHelpers.eventColor(event, labelStore: nil) == BovexaTheme.categoryColor(for: .social))
    }

    @Test func eventRecordIdUsesSeriesIdWhenPresentOtherwiseId() {
        let plain = makeEvent(id: "ev1", start: date(2026, 7, 24))
        #expect(EventHelpers.eventRecordId(plain) == "ev1")

        let occurrence = plain.withOccurrence(id: "ev1:2026-07-24", start: plain.start, end: nil, seriesId: "ev1", occurrenceDate: "2026-07-24")
        #expect(EventHelpers.eventRecordId(occurrence) == "ev1")
    }
}
