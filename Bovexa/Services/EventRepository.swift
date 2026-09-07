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
            AgendaEvent.self, collection: "agenda_events", filter: filter, sort: "start", expand: "contact,contacten", token: token
        )
        return RecurrenceExpander.expand(items.excludingDeclined(for: userId))
    }

    /// Eigen afspraken (incl. herhalingen uitgeklapt) — voor de dubbele-boeking-check.
    func fetchOwnEvents(userId: String, token: String) async throws -> [AgendaEvent] {
        let items = try await client.getFullList(
            AgendaEvent.self, collection: "agenda_events", filter: "owner = \"\(userId)\"", sort: "start", expand: "contact,contacten", token: token
        )
        return RecurrenceExpander.expand(items)
    }

    /// Faalt stil (geen bedrijf gekoppeld, netwerkfout, ...) — dan gewoon geen
    /// kleuren/logo. Wel één retry na een korte pauze: dit is de enige bron voor
    /// persoonskleuren en het bedrijfslogo, en één hikje bij het openen liet
    /// anders het hele scherm kleurloos achter tot de volgende focus.
    func listMembers(token: String) async -> MembersResponse? {
        if let first = try? await client.postCustom(MembersResponse.self, path: "/api/agenda/company/members", token: token) {
            return first
        }
        try? await Task.sleep(nanoseconds: 700_000_000)
        return try? await client.postCustom(MembersResponse.self, path: "/api/agenda/company/members", token: token)
    }

    private static let collection = "agenda_events"

    /// Creëer een event uit een kant-en-klare payload-body — gebruikt door zowel
    /// AppointmentCreatePayload (AI-planner, valkuil A) als AfwezigCreatePayload
    /// (valkuil I), die elk hun eigen requestBody bouwen.
    func createEvent(body: [String: Any], token: String) async throws -> AgendaEvent {
        try await client.createRecord(AgendaEvent.self, collection: Self.collection, body: body, token: token)
    }

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
    /// `notitie` gaat mee als de beheerder er iets bij schrijft ("kan niet, we zijn
    /// die week met te weinig"). Leeg laten raakt het notitieveld niet aan.
    func respondToAssignment(
        event: AgendaEvent, userId: String, status: String, token: String, notitie: String = ""
    ) async throws -> AgendaEvent {
        var nextStatus = event.assigneeStatus
        nextStatus[userId] = status
        let recordId = EventHelpers.eventRecordId(event)
        var body: [String: Any] = ["assignee_status": nextStatus]
        let schoon = notitie.trimmingCharacters(in: .whitespacesAndNewlines)
        if !schoon.isEmpty { body["notes"] = schoon }
        return try await client.updateRecord(AgendaEvent.self, collection: Self.collection, id: recordId, body: body, token: token)
    }
}
