import Testing
import Foundation
@testable import Bovexa

struct EventDeclinedFilterTests {
    private func makeEvent(id: String, owner: String, assigneeStatus: [String: String] = [:]) -> AgendaEvent {
        AgendaEvent(
            id: id, owner: owner, calendar: nil, category: nil, title: "Test",
            start: Date(timeIntervalSince1970: 0), end: nil, allDay: false, recurrence: nil,
            location: nil, notes: nil, klantNaam: nil, assigneeStatus: assigneeStatus,
            seriesId: nil, occurrenceDate: nil
        )
    }

    @Test func keepsOwnEventsRegardlessOfAssigneeStatus() {
        let event = makeEvent(id: "ev1", owner: "me", assigneeStatus: ["me": "declined"])
        #expect([event].excludingDeclined(for: "me").count == 1)
    }

    @Test func removesEventsIDeclined() {
        let event = makeEvent(id: "ev1", owner: "collega", assigneeStatus: ["me": "declined"])
        #expect([event].excludingDeclined(for: "me").isEmpty)
    }

    @Test func keepsEventsIAcceptedOrHaveNotAnswered() {
        let accepted = makeEvent(id: "ev1", owner: "collega", assigneeStatus: ["me": "accepted"])
        let pending = makeEvent(id: "ev2", owner: "collega", assigneeStatus: [:])
        #expect([accepted, pending].excludingDeclined(for: "me").count == 2)
    }

    @Test func keepsEventsWhenAssigneeStatusHasOnlyOtherUsers() {
        let event = makeEvent(id: "ev1", owner: "collega", assigneeStatus: ["ander": "declined"])
        #expect([event].excludingDeclined(for: "me").count == 1)
    }
}
