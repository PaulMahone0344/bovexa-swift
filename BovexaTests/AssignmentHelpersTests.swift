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
}
