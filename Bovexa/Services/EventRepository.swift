import Foundation

/// Events-datalaag: filterbouw, declined-filter, herhalingen uitklappen, ledenlijst.
final class EventRepository {
    private let client: PBClient

    init(client: PBClient = PBClient()) {
        self.client = client
    }

    func fetchAllEvents(userId: String, orgId: String?, token: String) async throws -> [AgendaEvent] {
        let filter: String
        if let orgId {
            filter = "(owner = \"\(userId)\" || org = \"\(orgId)\" || viewers.id ?= \"\(userId)\")"
        } else {
            filter = "(owner = \"\(userId)\" || viewers.id ?= \"\(userId)\")"
        }

        let items = try await client.getFullList(
            AgendaEvent.self, collection: "agenda_events", filter: filter, sort: "start", token: token
        )
        return RecurrenceExpander.expand(items.excludingDeclined(for: userId))
    }

    /// Eigen afspraken (incl. herhalingen uitgeklapt) — voor de dubbele-boeking-check.
    func fetchOwnEvents(userId: String, token: String) async throws -> [AgendaEvent] {
        let items = try await client.getFullList(
            AgendaEvent.self, collection: "agenda_events", filter: "owner = \"\(userId)\"", sort: "start", token: token
        )
        return RecurrenceExpander.expand(items)
    }

    /// Faalt stil (geen bedrijf gekoppeld, netwerkfout, ...) — dan gewoon geen kleuren/logo.
    func listMembers(token: String) async -> MembersResponse? {
        try? await client.postCustom(MembersResponse.self, path: "/api/agenda/company/members", token: token)
    }

    private static let collection = "agenda_events"

    /// Valkuil E: payload bevat exact de toegestane velden, nooit "source".
    func updateEvent(recordId: String, payload: EventUpdatePayload, token: String) async throws -> AgendaEvent {
        try await client.updateRecord(AgendaEvent.self, collection: Self.collection, id: recordId, body: payload.requestBody, token: token)
    }

    func deleteEvent(recordId: String, token: String) async throws {
        try await client.deleteRecord(collection: Self.collection, id: recordId, token: token)
    }

    /// Valkuil C: toegewezenen horen ALTIJD ook in viewers, ongeacht wat de gebruiker koos.
    func updateVisibility(recordId: String, visibility: String, viewers: [String], assignees: [String], token: String) async throws -> AgendaEvent {
        let body: [String: Any] = [
            "visibility": visibility,
            "viewers": EventViewers.union(viewers, assignees: assignees),
        ]
        return try await client.updateRecord(AgendaEvent.self, collection: Self.collection, id: recordId, body: body, token: token)
    }

    /// Valkuil B + A: schrijft alleen JOUW sleutel in de assignee_status-map, en altijd
    /// naar het echte record-id (series-id bij een uitgeklapte herhaling).
    func respondToAssignment(event: AgendaEvent, userId: String, status: String, token: String) async throws -> AgendaEvent {
        var nextStatus = event.assigneeStatus
        nextStatus[userId] = status
        let recordId = EventHelpers.eventRecordId(event)
        let body: [String: Any] = ["assignee_status": nextStatus]
        return try await client.updateRecord(AgendaEvent.self, collection: Self.collection, id: recordId, body: body, token: token)
    }
}
