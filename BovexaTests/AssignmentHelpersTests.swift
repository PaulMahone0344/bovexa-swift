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
        #expect(AssignmentHelpers.pendingCount(events, userId: "me") == 1)
    }

    @Test func pendingCountIsZeroWithoutAssignments() {
        #expect(AssignmentHelpers.pendingCount([], userId: "me") == 0)
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
        #expect(AssignmentHelpers.pendingEvents(events, userId: "me").map(\.id) == ["a"])
    }

    @Test func pendingEventsSortsNewestStartFirst() {
        let older = Date(timeIntervalSince1970: 1000)
        let newer = Date(timeIntervalSince1970: 2000)
        let events = [
            event(id: "old", owner: "collega", start: older, assignee: ["me"], status: [:]),
            event(id: "new", owner: "collega", start: newer, assignee: ["me"], status: [:]),
        ]
        #expect(AssignmentHelpers.pendingEvents(events, userId: "me").map(\.id) == ["new", "old"])
    }
}
