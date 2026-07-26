import Testing
import Foundation
@testable import Bovexa

/// Viewmodel-logica van het afspraak-detail: wie ziet welke knoppen (valkuil F —
/// server bepaalt uiteindelijk wat mag, de client toont bewerken/verwijderen alleen
/// voor de eigenaar) + optimistisch bijwerken met rollback.
@MainActor
struct EventDetailViewModelTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    private func makeEvent(
        id: String = "ev1", owner: String = "owner", assignee: [String] = [],
        assigneeStatus: [String: String] = [:], seriesId: String? = nil,
        visibilityRaw: String? = nil, viewers: [String] = [], isExternal: Bool = false
    ) -> AgendaEvent {
        AgendaEvent(
            id: id, owner: owner, calendar: nil, category: nil, title: "T",
            start: Date(), end: nil, allDay: false, recurrence: nil, location: nil, notes: nil,
            klantNaam: nil, assigneeStatus: assigneeStatus, seriesId: seriesId, occurrenceDate: nil,
            org: "org1", visibilityRaw: visibilityRaw, viewers: viewers, assignee: assignee,
            isExternal: isExternal
        )
    }

    private func makeRepository() -> EventRepository {
        EventRepository(client: PBClient(session: URLProtocolStub.makeSession()))
    }

    private func makeViewModel(
        event: AgendaEvent, currentUserId: String = "owner", currentUserOrgId: String? = "org1",
        reminderScheduler: FakeNotificationScheduler = FakeNotificationScheduler()
    ) -> EventDetailViewModel {
        EventDetailViewModel(
            event: event, currentUserId: currentUserId, currentUserOrgId: currentUserOrgId, token: "tok",
            repository: makeRepository(), reminderService: ReminderService(scheduler: reminderScheduler)
        )
    }

    // MARK: - wie ziet welke knoppen

    @Test func ownerCanDeleteAndEdit() {
        let vm = makeViewModel(event: makeEvent(owner: "owner"), currentUserId: "owner")
        #expect(vm.canDelete)
        #expect(vm.canEdit)
    }

    @Test func colleagueCannotDeleteOrEdit() {
        let vm = makeViewModel(event: makeEvent(owner: "owner"), currentUserId: "collega")
        #expect(!vm.canDelete)
        #expect(!vm.canEdit)
    }

    @Test func assignedUserWithoutStatusKeyCanRespond() {
        let vm = makeViewModel(event: makeEvent(assignee: ["collega"]), currentUserId: "collega")
        #expect(vm.myAssignmentStatus == "pending")
        #expect(vm.canRespond)
    }

    @Test func assignedUserWhoAlreadyAnsweredCannotRespondAgain() {
        let vm = makeViewModel(
            event: makeEvent(assignee: ["collega"], assigneeStatus: ["collega": "accepted"]),
            currentUserId: "collega"
        )
        #expect(!vm.canRespond)
    }

    @Test func unassignedUserCannotRespond() {
        let vm = makeViewModel(event: makeEvent(assignee: ["collega"]), currentUserId: "buitenstaander")
        #expect(vm.myAssignmentStatus == nil)
        #expect(!vm.canRespond)
    }

    @Test func isAssignedToMeBadgeOnlyForAssignedUser() {
        let event = makeEvent(assignee: ["collega"])
        #expect(makeViewModel(event: event, currentUserId: "collega").isAssignedToMe)
        #expect(!makeViewModel(event: event, currentUserId: "owner").isAssignedToMe)
    }

    @Test func visibilityPickerOnlyForOwnerWithOrg() {
        #expect(makeViewModel(event: makeEvent(owner: "owner"), currentUserId: "owner", currentUserOrgId: "org1").showVisibilityPicker)
        #expect(!makeViewModel(event: makeEvent(owner: "owner"), currentUserId: "owner", currentUserOrgId: nil).showVisibilityPicker)
        #expect(!makeViewModel(event: makeEvent(owner: "owner"), currentUserId: "collega", currentUserOrgId: "org1").showVisibilityPicker)
    }

    // MARK: - extern event is read-only (m9 plak 5, valkuil B)

    @Test func externalEventCannotBeEditedOrDeletedEvenIfOwnerMatches() {
        let vm = makeViewModel(event: makeEvent(owner: "owner", isExternal: true), currentUserId: "owner")
        #expect(!vm.canDelete)
        #expect(!vm.canEdit)
        #expect(!vm.showVisibilityPicker)
    }

    @Test func externalEventCannotBeRespondedToEvenIfSomehowAssigned() {
        let vm = makeViewModel(event: makeEvent(assignee: ["collega"], isExternal: true), currentUserId: "collega")
        #expect(!vm.canRespond)
    }

    @Test func normalizedVisibilityFallsBackToCompanyForLegacyValues() {
        #expect(makeViewModel(event: makeEvent(visibilityRaw: "private")).normalizedVisibility == "private")
        #expect(makeViewModel(event: makeEvent(visibilityRaw: "company")).normalizedVisibility == "company")
        #expect(makeViewModel(event: makeEvent(visibilityRaw: "busy")).normalizedVisibility == "company")
        #expect(makeViewModel(event: makeEvent(visibilityRaw: nil)).normalizedVisibility == "company")
    }

    // MARK: - delete

    @Test func deleteAsOwnerSucceedsAndCancelsReminder() async {
        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "DELETE")
            return (204, Data())
        }
        let scheduler = FakeNotificationScheduler()
        let vm = makeViewModel(event: makeEvent(id: "ev1", owner: "owner"), currentUserId: "owner", reminderScheduler: scheduler)
        let success = await vm.delete()
        #expect(success)
        #expect(scheduler.canceledIdentifiers == ["bovexaflow_reminder_ev1"])
        #expect(!vm.deleteFailedAlert)
    }

    @Test func deleteFailureSetsAlertAndReturnsFalse() async {
        URLProtocolStub.requestHandler = { _ in (500, Data("{}".utf8)) }
        let vm = makeViewModel(event: makeEvent(owner: "owner"), currentUserId: "owner")
        let success = await vm.delete()
        #expect(!success)
        #expect(vm.deleteFailedAlert)
    }

    // MARK: - respond (valkuil B + optimistisch met rollback)

    @Test func respondAcceptedUpdatesEventFromServer() async {
        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"id":"ev1","owner":"owner","title":"T","start":"2026-08-03 09:00:00.000Z","all_day":false,"assignee":["collega"],"assignee_status":{"collega":"accepted"}}
            """.data(using: .utf8)!
            return (200, json)
        }
        let vm = makeViewModel(event: makeEvent(id: "ev1", assignee: ["collega"]), currentUserId: "collega")
        await vm.respond("accepted")
        #expect(vm.event.assigneeStatus["collega"] == "accepted")
        #expect(!vm.respondFailedAlert)
    }

    @Test func respondFailureRollsBackToPreviousEventAndSetsAlert() async {
        URLProtocolStub.requestHandler = { _ in (500, Data("{}".utf8)) }
        let original = makeEvent(id: "ev1", assignee: ["collega"])
        let vm = makeViewModel(event: original, currentUserId: "collega")
        await vm.respond("declined")
        #expect(vm.event.assigneeStatus["collega"] == nil)
        #expect(vm.respondFailedAlert)
    }

    @Test func respondWhenNotAllowedDoesNothing() async {
        // Niet toegewezen — mag niet reageren, ook al wordt respond() aangeroepen.
        URLProtocolStub.requestHandler = { _ in
            Issue.record("mocht geen netwerkverzoek doen")
            return (500, Data())
        }
        let vm = makeViewModel(event: makeEvent(assignee: []), currentUserId: "buitenstaander")
        await vm.respond("accepted")
        #expect(vm.event.assigneeStatus.isEmpty)
    }

    // MARK: - changeVisibility (optimistisch met rollback)

    @Test func changeVisibilitySucceedsAndUpdatesFromServer() async {
        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"id":"ev1","owner":"owner","title":"T","start":"2026-08-03 09:00:00.000Z","all_day":false,"visibility":"private"}
            """.data(using: .utf8)!
            return (200, json)
        }
        let vm = makeViewModel(event: makeEvent(id: "ev1", owner: "owner"), currentUserId: "owner")
        await vm.changeVisibility("private")
        #expect(vm.event.visibilityRaw == "private")
        #expect(!vm.visibilityFailedAlert)
    }

    @Test func changeVisibilityFailureRollsBack() async {
        URLProtocolStub.requestHandler = { _ in (500, Data("{}".utf8)) }
        let original = makeEvent(id: "ev1", owner: "owner", visibilityRaw: "company")
        let vm = makeViewModel(event: original, currentUserId: "owner")
        await vm.changeVisibility("private")
        #expect(vm.event.visibilityRaw == "company")
        #expect(vm.visibilityFailedAlert)
    }
}
