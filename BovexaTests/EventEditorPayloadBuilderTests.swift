import Testing
import Foundation
@testable import Bovexa

/// Payload-bouwer voor EventEditor.save() — viewers-union (valkuil C) en
/// assignee_status-map (valkuil B), zoals de save() in de RN-app.
struct EventEditorPayloadBuilderTests {
    private func date(_ h: Int) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 8; comps.day = 3; comps.hour = h
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    private func originalEvent(owner: String = "owner", viewers: [String] = [], assigneeStatus: [String: String] = [:]) -> AgendaEvent {
        AgendaEvent(
            id: "ev1", owner: owner, calendar: nil, category: nil, title: "Oud", start: date(9), end: date(10),
            allDay: false, recurrence: nil, location: nil, notes: nil, klantNaam: nil,
            assigneeStatus: assigneeStatus, seriesId: nil, occurrenceDate: nil,
            viewers: viewers
        )
    }

    @Test func trimsTextFieldsAndUsesGivenTimes() {
        let payload = EventEditorPayloadBuilder.build(
            title: "  Klant Jansen  ", category: .work, start: date(9), end: date(10),
            notes: "  memo  ", klantNaam: "  Jansen  ", klantTelefoon: "  0612345678  ",
            reminderMin: 15, assignee: [], originalEvent: originalEvent()
        )
        #expect(payload.title == "Klant Jansen")
        #expect(payload.notes == "memo")
        #expect(payload.klantNaam == "Jansen")
        #expect(payload.klantTelefoon == "0612345678")
        #expect(payload.start == date(9))
        #expect(payload.end == date(10))
    }

    @Test func viewersUnionAddsNewAssigneesToExistingViewers() {
        let payload = EventEditorPayloadBuilder.build(
            title: "T", category: .work, start: date(9), end: date(10), notes: "", klantNaam: "", klantTelefoon: "",
            reminderMin: 0, assignee: ["u2"], originalEvent: originalEvent(viewers: ["u1"])
        )
        #expect(payload.viewers == ["u1", "u2"])
    }

    @Test func statusMapKeepsOwnerAcceptedAndPreservesExistingAnswers() {
        let payload = EventEditorPayloadBuilder.build(
            title: "T", category: .work, start: date(9), end: date(10), notes: "", klantNaam: "", klantTelefoon: "",
            reminderMin: 0, assignee: ["owner", "u2", "u3"],
            originalEvent: originalEvent(owner: "owner", assigneeStatus: ["u2": "declined"])
        )
        #expect(payload.assigneeStatus == ["owner": "accepted", "u2": "declined", "u3": "pending"])
    }

    @Test func withoutLabelOmitsFieldFromRequestBody() {
        let payload = EventEditorPayloadBuilder.build(
            title: "T", category: .work, start: date(9), end: date(10), notes: "", klantNaam: "", klantTelefoon: "",
            reminderMin: 0, assignee: [], originalEvent: originalEvent()
        )
        #expect(payload.requestBody["label"] == nil)
    }

    @Test func chosenLabelIsIncludedInRequestBody() {
        let payload = EventEditorPayloadBuilder.build(
            title: "T", category: .work, start: date(9), end: date(10), notes: "", klantNaam: "", klantTelefoon: "",
            reminderMin: 0, assignee: [], originalEvent: originalEvent(), label: "l1"
        )
        #expect(payload.requestBody["label"] as? String == "l1")
    }

    @Test func removedAssigneeDropsOutOfStatusMap() {
        let payload = EventEditorPayloadBuilder.build(
            title: "T", category: .work, start: date(9), end: date(10), notes: "", klantNaam: "", klantTelefoon: "",
            reminderMin: 0, assignee: ["owner"],
            originalEvent: originalEvent(owner: "owner", assigneeStatus: ["owner": "accepted", "u2": "pending"])
        )
        #expect(payload.assigneeStatus == ["owner": "accepted"])
    }
}
