import Testing
import Foundation
@testable import Bovexa

/// Belangrijkste testplak van m2 (valkuil B) — geport uit assignments.test.ts-gedrag.
struct AssignmentHelpersTests {
    // MARK: - nextStatusMap

    @Test func ownerAssigningSelfGetsAcceptedDirectly() {
        let map = AssignmentHelpers.nextStatusMap(assignees: ["owner"], ownerId: "owner")
        #expect(map == ["owner": "accepted"])
    }

    @Test func newAssigneeWithoutPreviousAnswerGetsPending() {
        let map = AssignmentHelpers.nextStatusMap(assignees: ["owner", "collega"], ownerId: "owner")
        #expect(map == ["owner": "accepted", "collega": "pending"])
    }

    @Test func existingAnswerIsPreservedWhenStillAssigned() {
        let map = AssignmentHelpers.nextStatusMap(
            assignees: ["owner", "collega"], ownerId: "owner", previous: ["collega": "declined"]
        )
        #expect(map["collega"] == "declined")
    }

    @Test func existingAcceptedAnswerIsPreservedWhenStillAssigned() {
        let map = AssignmentHelpers.nextStatusMap(
            assignees: ["owner", "collega"], ownerId: "owner", previous: ["collega": "accepted"]
        )
        #expect(map["collega"] == "accepted")
    }

    @Test func removedAssigneeDisappearsFromMap() {
        let map = AssignmentHelpers.nextStatusMap(
            assignees: ["owner"], ownerId: "owner", previous: ["owner": "accepted", "collega": "pending"]
        )
        #expect(map["collega"] == nil)
        #expect(map.count == 1)
    }

    @Test func emptyAssigneesProducesEmptyMap() {
        let map = AssignmentHelpers.nextStatusMap(assignees: [], ownerId: "owner", previous: ["collega": "accepted"])
        #expect(map.isEmpty)
    }

    // MARK: - assignmentStatus

    @Test func statusIsNilWhenNotAssigned() {
        let status = AssignmentHelpers.assignmentStatus(assignees: ["collega"], statusMap: [:], userId: "buitenstaander")
        #expect(status == nil)
    }

    @Test func statusIsPendingWhenAssignedWithoutMapEntry() {
        let status = AssignmentHelpers.assignmentStatus(assignees: ["collega"], statusMap: [:], userId: "collega")
        #expect(status == "pending")
    }

    @Test func statusReflectsMapEntryWhenAssigned() {
        let status = AssignmentHelpers.assignmentStatus(
            assignees: ["collega"], statusMap: ["collega": "declined"], userId: "collega"
        )
        #expect(status == "declined")
    }

    // MARK: - pendingCount (m6, Profiel-teller)

    private func event(id: String, assignee: [String], status: [String: String]) -> AgendaEvent {
        AgendaEvent(
            id: id, owner: "iemand-anders", calendar: nil, category: nil, title: "Afspraak",
            start: Date(), end: nil, allDay: false, recurrence: nil, location: nil, notes: nil,
            klantNaam: nil, assigneeStatus: status, seriesId: nil, occurrenceDate: nil,
            assignee: assignee
        )
    }

    @Test func pendingCountCountsOnlyPendingAssignmentsForUser() {
        let events = [
            event(id: "a", assignee: ["me"], status: [:]),
            event(id: "b", assignee: ["me"], status: ["me": "accepted"]),
            event(id: "c", assignee: ["me"], status: ["me": "declined"]),
            event(id: "d", assignee: ["collega"], status: [:]),
        ]
        #expect(AssignmentHelpers.pendingCount(events, userId: "me", now: .distantPast) == 1)
    }

    @Test func pendingCountIsZeroWithoutAssignments() {
        #expect(AssignmentHelpers.pendingCount([], userId: "me", now: .distantPast) == 0)
    }

    // MARK: - pendingEvents (m6, Meldingen-scherm)

    private func event(id: String, owner: String, start: Date, assignee: [String], status: [String: String]) -> AgendaEvent {
        AgendaEvent(
            id: id, owner: owner, calendar: nil, category: nil, title: "Afspraak",
            start: start, end: nil, allDay: false, recurrence: nil, location: nil, notes: nil,
            klantNaam: nil, assigneeStatus: status, seriesId: nil, occurrenceDate: nil,
            assignee: assignee
        )
    }

    @Test func pendingEventsExcludesOwnAndAcceptedAndDeclined() {
        let events = [
            event(id: "a", owner: "collega", start: Date(), assignee: ["me"], status: [:]),
            event(id: "b", owner: "collega", start: Date(), assignee: ["me"], status: ["me": "accepted"]),
            event(id: "c", owner: "collega", start: Date(), assignee: ["me"], status: ["me": "declined"]),
            event(id: "d", owner: "me", start: Date(), assignee: ["me"], status: [:]),
        ]
        #expect(AssignmentHelpers.pendingEvents(events, userId: "me", now: .distantPast).map(\.id) == ["a"])
    }

    @Test func pendingEventsSortsNewestStartFirst() {
        let older = Date(timeIntervalSince1970: 1000)
        let newer = Date(timeIntervalSince1970: 2000)
        let events = [
            event(id: "old", owner: "collega", start: older, assignee: ["me"], status: [:]),
            event(id: "new", owner: "collega", start: newer, assignee: ["me"], status: [:]),
        ]
        #expect(AssignmentHelpers.pendingEvents(events, userId: "me", now: .distantPast).map(\.id) == ["new", "old"])
    }

    // MARK: - Herhalingen ontdubbelen (M11 plak 3g)

    private func occurrence(id: String, seriesId: String, start: Date) -> AgendaEvent {
        AgendaEvent(
            id: id, owner: "collega", calendar: nil, category: nil, title: "Wekelijks overleg",
            start: start, end: nil, allDay: false, recurrence: "FREQ=WEEKLY", location: nil, notes: nil,
            klantNaam: nil, assigneeStatus: [:], seriesId: seriesId, occurrenceDate: nil,
            assignee: ["me"]
        )
    }

    /// RecurrenceExpander klapt een herhaling uit tot 365 dagen. Eén toewijzing op
    /// een wekelijkse afspraak stond daardoor als tientallen losse kaarten onder
    /// WACHT OP JOUW AKKOORD, terwijl er maar één antwoord te geven is.
    @Test func pendingEventsKeepsOneCardPerSeries() {
        let events = (0..<5).map { week in
            occurrence(id: "serie1:2026-09-0\(week + 1)", seriesId: "serie1", start: Date(timeIntervalSince1970: 5000 + Double(week) * 1000))
        }
        let result = AssignmentHelpers.pendingEvents(events, userId: "me", now: .distantPast)
        #expect(result.count == 1)
        // De eerstvolgende bezetting blijft staan, niet een willekeurige.
        #expect(result.first?.id == "serie1:2026-09-01")
    }

    @Test func expiredPendingEventsKeepsOneCardPerSeries() {
        // Binnen het venster van 30 dagen (4h), anders vallen ze er sowieso uit.
        let nu = Date(timeIntervalSince1970: 1_800_000_000)
        let events = (0..<4).map { week in
            occurrence(
                id: "serie1:2026-01-0\(week + 1)", seriesId: "serie1",
                start: nu.addingTimeInterval(-Double(week + 1) * 24 * 60 * 60)
            )
        }
        let result = AssignmentHelpers.expiredPendingEvents(events, userId: "me", now: nu)
        #expect(result.count == 1)
    }

    /// 4h: een toewijzing die maanden geleden verliep hoort niet eeuwig in
    /// VERLOPEN te blijven staan.
    @Test func expiredPendingEventsDropsAnythingOlderThanThirtyDays() {
        let nu = Date(timeIntervalSince1970: 1_800_000_000)
        let recent = occurrence(id: "a", seriesId: "a", start: nu.addingTimeInterval(-5 * 24 * 60 * 60))
        let oud = occurrence(id: "b", seriesId: "b", start: nu.addingTimeInterval(-60 * 24 * 60 * 60))

        let result = AssignmentHelpers.expiredPendingEvents([recent, oud], userId: "me", now: nu)

        #expect(result.map(\.id) == ["a"])
    }

    @Test func twoDifferentSeriesStayTwoCards() {
        let events = [
            occurrence(id: "serie1:2026-09-01", seriesId: "serie1", start: Date(timeIntervalSince1970: 5000)),
            occurrence(id: "serie1:2026-09-08", seriesId: "serie1", start: Date(timeIntervalSince1970: 6000)),
            occurrence(id: "serie2:2026-09-02", seriesId: "serie2", start: Date(timeIntervalSince1970: 7000)),
        ]
        let result = AssignmentHelpers.pendingEvents(events, userId: "me", now: .distantPast)
        #expect(Set(result.map { EventHelpers.eventRecordId($0) }) == ["serie1", "serie2"])
        #expect(result.count == 2)
    }

    @Test func losseAfsprakenWordenNietOntdubbeld() {
        let events = [
            event(id: "a", owner: "collega", start: Date(timeIntervalSince1970: 1000), assignee: ["me"], status: [:]),
            event(id: "b", owner: "collega", start: Date(timeIntervalSince1970: 2000), assignee: ["me"], status: [:]),
        ]
        #expect(AssignmentHelpers.pendingEvents(events, userId: "me", now: .distantPast).count == 2)
    }
}
