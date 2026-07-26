import Testing
import Foundation
@testable import Bovexa

/// Toewijzingen op een afspraak die al geweest is bleven eeuwig om akkoord vragen:
/// op 26 juli stonden er twee van vrijdag 24 juli in Meldingen, met knoppen
/// Accepteren en Weigeren die niets meer betekenen, en ze bleven meetellen in de
/// teller en de stip op Profiel.
struct AssignmentExpiryTests {
    private let now = Date(timeIntervalSince1970: 1_784_000_000)

    private func event(
        id: String, startOffsetHours: Double, durationHours: Double? = 1, allDay: Bool = false
    ) -> AgendaEvent {
        let start = now.addingTimeInterval(startOffsetHours * 3600)
        return AgendaEvent(
            id: id, owner: "baas", calendar: nil, category: .work, title: "Klus",
            start: start, end: durationHours.map { start.addingTimeInterval($0 * 3600) },
            allDay: allDay, recurrence: nil, location: nil, notes: nil, klantNaam: nil,
            assigneeStatus: ["mij": "pending"], seriesId: nil, occurrenceDate: nil,
            assignee: ["mij"]
        )
    }

    @Test("Een toewijzing in de toekomst wacht nog op akkoord")
    func futureIsActionable() {
        let toekomst = event(id: "a", startOffsetHours: 24)
        #expect(AssignmentHelpers.pendingEvents([toekomst], userId: "mij", now: now).map(\.id) == ["a"])
        #expect(AssignmentHelpers.expiredPendingEvents([toekomst], userId: "mij", now: now).isEmpty)
    }

    @Test("Een toewijzing op een afspraak die al voorbij is, is verlopen")
    func pastIsExpired() {
        let verleden = event(id: "b", startOffsetHours: -48)
        #expect(AssignmentHelpers.pendingEvents([verleden], userId: "mij", now: now).isEmpty)
        #expect(AssignmentHelpers.expiredPendingEvents([verleden], userId: "mij", now: now).map(\.id) == ["b"])
    }

    /// Een afspraak die nu loopt is nog niet verlopen — je kunt er nog naartoe.
    @Test("Een afspraak die nu bezig is blijft actueel")
    func runningNowStaysActionable() {
        let bezig = event(id: "c", startOffsetHours: -0.5, durationHours: 2)
        #expect(AssignmentHelpers.pendingEvents([bezig], userId: "mij", now: now).map(\.id) == ["c"])
    }

    /// Zonder eindtijd loopt een afspraak tot het eind van zijn dag. Een toewijzing
    /// voor vandaag 09:00 moet je om 11:30 nog kunnen beantwoorden; terugvallen op de
    /// starttijd bestempelde die meteen als verlopen.
    @Test("Zonder eindtijd blijft de afspraak zijn hele dag actueel")
    func noEndTimeLastsUntilEndOfDay() {
        let vanmorgen = event(id: "d", startOffsetHours: -3, durationHours: nil)
        let straks = event(id: "e", startOffsetHours: 1, durationHours: nil)
        let gisteren = event(id: "f", startOffsetHours: -30, durationHours: nil)
        #expect(Calendar.current.isDate(vanmorgen.start, inSameDayAs: now)) // anders test dit niets
        #expect(Set(AssignmentHelpers.pendingEvents([vanmorgen, straks, gisteren], userId: "mij", now: now).map(\.id)) == ["d", "e"])
        #expect(AssignmentHelpers.expiredPendingEvents([vanmorgen, straks, gisteren], userId: "mij", now: now).map(\.id) == ["f"])
    }

    /// Dit is de reden dat de stip op Profiel bleef branden.
    @Test("De teller telt verlopen toewijzingen niet mee")
    func countIgnoresExpired() {
        let events = [event(id: "f", startOffsetHours: -48), event(id: "g", startOffsetHours: 24)]
        #expect(AssignmentHelpers.pendingCount(events, userId: "mij", now: now) == 1)
    }

    @Test("Beide lijsten staan nieuwste eerst")
    func bothListsNewestFirst() {
        let events = [
            event(id: "oud", startOffsetHours: -72),
            event(id: "recent", startOffsetHours: -24),
            event(id: "morgen", startOffsetHours: 24),
            event(id: "overmorgen", startOffsetHours: 48),
        ]
        #expect(AssignmentHelpers.pendingEvents(events, userId: "mij", now: now).map(\.id) == ["overmorgen", "morgen"])
        #expect(AssignmentHelpers.expiredPendingEvents(events, userId: "mij", now: now).map(\.id) == ["recent", "oud"])
    }
}
